import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/friends_roster.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestor de estado para la funcionalidad "Miremos Juntos" (Watch Party) (SPEC-36 y SPEC-37).
class WatchPartyProvider extends ChangeNotifier {
  static const String keyWatchPartyEnabled = 'watch_party_enabled';

  final AppPreferences preferences;
  final WatchPartyService service;
  final DeviceIdentityService identityService;

  bool _enabled = false;
  String _userCode = 'MOAI-????';
  String? _nickname;
  String _deviceId = '';
  final _roster = FriendsRoster();
  List<FriendInfo> _friendRequests = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _presenceRefreshTimer;
  String? _currentChannelId;
  String? _currentChannelName;
  Timer? _channelReportDebounceTimer;
  RealtimeChannel? _devicesRealtimeChannel;
  RealtimeChannel? _presenceRealtimeChannel;
  bool _isDisposed = false;

  WatchPartyProvider({
    required this.preferences,
    required this.service,
    required this.identityService,
  }) {
    _init();
  }

  bool get enabled => _enabled;
  String get userCode {
    if (_userCode == 'MOAI-????' || _userCode.isEmpty) {
      final savedCode = identityService.getUserCode();
      if (savedCode != null &&
          savedCode.trim().isNotEmpty &&
          savedCode != 'MOAI-????') {
        _userCode = savedCode.trim();
      }
    }
    return _userCode;
  }

  String? get nickname {
    if (_nickname == null || _nickname!.trim().isEmpty) {
      final saved = identityService.getNickname();
      if (saved != null && saved.trim().isNotEmpty) {
        _nickname = saved.trim();
      }
    }
    return _nickname;
  }

  /// Nombre local preferido para mostrar a otros usuarios (nickname o fallback a userCode).
  String get myNickname =>
      (_nickname?.trim().isNotEmpty == true) ? _nickname!.trim() : userCode;
  String get deviceId => _deviceId;
  List<FriendInfo> get friends => _roster.friends;
  List<FriendInfo> get friendRequests => List.unmodifiable(_friendRequests);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Indica si al menos un amigo está en línea en este momento.
  bool get hasOnlineFriends => _roster.friends.any((f) => f.isOnline);

  /// Cantidad de amigos conectados en tiempo real.
  int get onlineFriendsCount =>
      _roster.friends.where((f) => f.isOnline).length;

  /// ID del canal actualmente sintonizado y confirmado tras debounce (SPEC-37).
  String? get currentChannelId => _currentChannelId;

  /// Nombre del canal actualmente sintonizado.
  String? get currentChannelName => _currentChannelName;

  /// Lista de amigos que están mirando el mismo canal actualmente (SPEC-37).
  List<FriendInfo> get friendsWatchingCurrentChannel {
    if (!_enabled) return const [];
    return _roster.watching(_currentChannelId, _currentChannelName);
  }

  /// Indica si hay al menos un amigo mirando el mismo canal.
  bool get hasFriendsInSameChannel => friendsWatchingCurrentChannel.isNotEmpty;

  void _init() {
    _deviceId = identityService.getOrCreateDeviceId();
    _enabled = preferences.readPreferenceBool(keyWatchPartyEnabled);
    _userCode = identityService.getUserCode() ?? 'MOAI-????';
    _nickname = identityService.getNickname();

    if (_enabled) {
      ensureUserCode();
      loadFriends();
      fetchNickname(forceRemote: true);
      _startPresenceTimer();
      _subscribeToDevicesRealtime();
      _subscribeToPresenceRealtime();
    }
  }

  /// Obtiene o sincroniza el nickname desde preferencias locales o Supabase.
  Future<String?> fetchNickname({bool forceRemote = false}) async {
    if (!forceRemote) {
      final local = nickname;
      if (local != null && local.isNotEmpty) {
        return local;
      }
    }

    if (_deviceId.isNotEmpty) {
      try {
        final remote = await service.getDeviceNickname(_deviceId);
        if (remote != null && remote.trim().isNotEmpty) {
          if (_nickname != remote.trim()) {
            _nickname = remote.trim();
            await identityService.saveNickname(_nickname!);
            notifyListeners();
          }
          return _nickname;
        }
      } catch (e) {
        debugPrint('[WatchPartyProvider] $e');
      }
    }
    return _nickname;
  }

  /// Actualiza y persiste el nickname en preferencias y en Supabase.
  Future<void> updateNickname(String newNickname) async {
    final trimmed = newNickname.trim();
    if (trimmed.isEmpty) return;

    _nickname = trimmed;
    await identityService.saveNickname(trimmed);
    notifyListeners();

    if (_deviceId.isNotEmpty) {
      await service.updateNickname(deviceId: _deviceId, nickname: trimmed);
    }
  }

  /// Asegura que el código de usuario propio esté cargado (preferencias o Supabase).
  Future<void> ensureUserCode() async {
    final savedCode = identityService.getUserCode();
    if (savedCode != null &&
        savedCode.trim().isNotEmpty &&
        savedCode != 'MOAI-????') {
      if (_userCode != savedCode) {
        _userCode = savedCode;
        notifyListeners();
      }
      return;
    }

    if (_deviceId.isNotEmpty) {
      try {
        final remoteCode = await service.getDeviceUserCode(_deviceId);
        if (remoteCode != null && remoteCode.trim().isNotEmpty) {
          updateUserCode(remoteCode.trim());
        }
      } catch (e) {
        debugPrint('[WatchPartyProvider] $e');
      }
    }
  }

  /// Actualiza y persiste el código propio del usuario.
  void updateUserCode(String code) {
    if (_userCode != code) {
      _userCode = code;
      identityService.saveUserCode(code);
      notifyListeners();
    }
  }

  /// Conmuta el switch "Miremos Juntos" (Reglas RB-01, RB-02, RB-03).
  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await preferences.saveBool(keyWatchPartyEnabled, value);

    if (_enabled) {
      // Al activar, asegurar código, cargar amigos y arrancar refresco de presencia
      await ensureUserCode();
      await loadFriends();
      _startPresenceTimer();
      _subscribeToDevicesRealtime();
      _subscribeToPresenceRealtime();
    } else {
      // Al desactivar, detener timers, desuscribir realtime y limpiar canal
      _presenceRefreshTimer?.cancel();
      _presenceRefreshTimer = null;
      _channelReportDebounceTimer?.cancel();
      _channelReportDebounceTimer = null;
      _unsubscribeFromDevicesRealtime();
      _unsubscribeFromPresenceRealtime();
      if (_currentChannelId != null) {
        _currentChannelId = null;
        _currentChannelName = null;
        if (_deviceId.isNotEmpty) {
          unawaited(service.reportCurrentChannel(deviceId: _deviceId));
        }
      }
    }

    notifyListeners();
  }

  /// Carga o refresca la lista de amigos y su estado de presencia en tiempo real.
  Future<void> loadFriends({bool showLoading = false}) async {
    if (_deviceId.isEmpty) return;

    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    final before = _visibleState();
    try {
      _roster.replace(await service.getFriends(_deviceId));
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    try {
      final updatedRequests = await service.getFriendRequests(_deviceId);
      _friendRequests = updatedRequests;
    } catch (e) {
      debugPrint('[WatchPartyProvider] $e');
    }

    if (showLoading) {
      _isLoading = false;
    }
    // El sondeo corre cada 15 s: notificar solo si cambió algo visible, para no
    // reconstruir el overlay sobre el video (SPEC-50 §6.1).
    if (showLoading || _visibleState() != before) notifyListeners();
  }

  /// Lo que la UI muestra de amigos y solicitudes; `isOnline` depende de la hora.
  String _visibleState() => [
        for (final f in _roster.friends)
          '${f.deviceId}|${f.displayName}|${f.isOnline}|'
              '${f.currentChannelId}|${f.currentChannelName}',
        '#',
        for (final r in _friendRequests) r.deviceId,
        '#${_errorMessage ?? ''}',
      ].join(';');

  /// Agrega un nuevo amigo usando su código (ej. "7421" o "MOAI-7421").
  Future<void> addFriend(String friendCodeInput) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newFriend = await service.addFriend(
        deviceId: _deviceId,
        myUserCode: _userCode,
        friendUserCodeInput: friendCodeInput,
      );

      // Reemplazar o insertar en la lista local
      _roster.upsert(newFriend);
      // Remover de solicitudes si estaba en la lista de solicitudes pendientes
      _friendRequests = _friendRequests
          .where((r) => r.deviceId != newFriend.deviceId)
          .toList();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Acepta una solicitud de amistad entrante agregando al usuario por su código.
  Future<void> acceptFriendRequest(FriendInfo request) async {
    await addFriend(request.userCode);
  }

  /// Elimina un amigo existente de la lista.
  Future<void> removeFriend(String friendDeviceId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await service.removeFriend(
        deviceId: _deviceId,
        friendDeviceId: friendDeviceId,
      );

      _roster.remove(friendDeviceId);
      await loadFriends();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Publica el canal en reproducción. Adultos y null no se informan a amigos.
  void reportPlayingChannel(Channel? channel) {
    if (channel == null || channel.isAdult) {
      reportCurrentChannel();
      return;
    }
    reportCurrentChannel(channelId: channel.id, channelName: channel.name);
  }

  /// Reporta el canal sintonizado de forma inmediata (actualiza estado local y Supabase).
  /// Si [channelId] es null, limpia de inmediato en Supabase y notifica a los listeners.
  void reportCurrentChannel({String? channelId, String? channelName}) {
    if (!_enabled) return;

    final normalizedId = (channelId != null && channelId.trim().isNotEmpty)
        ? channelId.trim()
        : null;
    final normalizedName =
        (channelName != null && channelName.trim().isNotEmpty)
        ? channelName.trim()
        : null;

    // Si ya está exactamente en este canal reportado, no duplicar llamadas
    if (_currentChannelId == normalizedId &&
        _currentChannelName == normalizedName) {
      return;
    }

    _channelReportDebounceTimer?.cancel();
    _channelReportDebounceTimer = null;

    _currentChannelId = normalizedId;
    _currentChannelName = normalizedName;
    _roster.resetNotified();
    notifyListeners();

    if (normalizedId != null) {
      _checkAndNotifyWatchingFriends();
    }

    if (_deviceId.isNotEmpty) {
      if (_presenceRealtimeChannel != null) {
        unawaited(
          _presenceRealtimeChannel!.track({
            'device_id': _deviceId,
            'user_code': _userCode,
            'nickname': _nickname,
            'channel_id': normalizedId,
            'channel_name': normalizedName,
          }),
        );
      }

      unawaited(
        service.reportCurrentChannel(
          deviceId: _deviceId,
          channelId: normalizedId,
          channelName: normalizedName,
        ),
      );
    }
  }

  void _checkAndNotifyWatchingFriends() {
    _roster
        .takeNewWatchers(_currentChannelId, _currentChannelName)
        .forEach(notifyFriendJoinedChannel);
  }

  void _subscribeToPresenceRealtime() {
    if (_deviceId.isEmpty) return;
    _unsubscribeFromPresenceRealtime();
    try {
      _presenceRealtimeChannel = service.joinWatchPartyPresence(
        deviceId: _deviceId,
        initialPayload: {
          'device_id': _deviceId,
          'user_code': _userCode,
          'nickname': _nickname,
          'channel_id': _currentChannelId,
          'channel_name': _currentChannelName,
        },
        onPresenceUpdated: _onRealtimePresencesUpdated,
      );
    } catch (e) {
      debugPrint('[WatchPartyProvider] $e');
    }
  }

  void _unsubscribeFromPresenceRealtime() {
    try {
      _presenceRealtimeChannel?.untrack();
      _presenceRealtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[WatchPartyProvider] $e');
    }
    _presenceRealtimeChannel = null;
  }

  void _onRealtimePresencesUpdated(List<Map<String, dynamic>> activePresences) {
    if (_isDisposed || !_enabled) return;
    if (_roster.applyPresences(activePresences)) {
      _checkAndNotifyWatchingFriends();
      notifyListeners();
    }
  }

  void _startPresenceTimer() {
    _presenceRefreshTimer?.cancel();
    // Consultar presencia cada 15 segundos mientras la app esté abierta y la función activa
    _presenceRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_enabled) {
        loadFriends();
      }
    });
  }

  void _subscribeToDevicesRealtime() {
    try {
      _devicesRealtimeChannel = service.subscribeToDevicesUpdates(
        onDeviceUpdated: _onDeviceRecordUpdated,
      );
    } catch (e) {
      debugPrint('[WatchPartyProvider] $e');
    }
  }

  void _unsubscribeFromDevicesRealtime() {
    try {
      _devicesRealtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[WatchPartyProvider] $e');
    }
    _devicesRealtimeChannel = null;
  }

  final StreamController<String> _joinedChannelNotificationsController =
      StreamController<String>.broadcast();

  Stream<String> get joinedChannelNotificationsStream =>
      _joinedChannelNotificationsController.stream;

  void notifyFriendJoinedChannel(String friendName) {
    if (!_isDisposed) {
      _joinedChannelNotificationsController.add(friendName);
    }
  }

  void _onDeviceRecordUpdated(Map<String, dynamic> record) {
    final updatedDeviceId = record['device_id'] as String?;
    if (updatedDeviceId == null || updatedDeviceId.isEmpty) return;

    // Si el registro actualizado es nuestro propio dispositivo (ej. modificado en Supabase dashboard)
    if (updatedDeviceId == _deviceId) {
      final newNick = record['nickname'] as String?;
      if (newNick != null &&
          newNick.trim().isNotEmpty &&
          newNick.trim() != _nickname) {
        _nickname = newNick.trim();
        identityService.saveNickname(_nickname!);
        notifyListeners();
      }
      return;
    }

    final joinedName = _roster.applyDeviceRecord(
      record,
      channelId: _currentChannelId,
      channelName: _currentChannelName,
    );
    if (joinedName == null) return;
    // La lista cambió siempre; el aviso, solo si entró al canal y no se avisó ya.
    notifyListeners();
    if (joinedName.isNotEmpty) notifyFriendJoinedChannel(joinedName);
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _presenceRefreshTimer?.cancel();
    _channelReportDebounceTimer?.cancel();
    _unsubscribeFromDevicesRealtime();
    _unsubscribeFromPresenceRealtime();
    _joinedChannelNotificationsController.close();
    super.dispose();
  }
}
