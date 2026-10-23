import 'package:moai3/models/friend_info.dart';

/// Lista de amigos de Miremos Juntos y su estado en vivo, sin red ni UI.
///
/// Fusiona la presencia de Realtime y los cambios de la tabla de dispositivos,
/// mantiene el orden (en línea primero, luego por nombre) y decide a qué amigos
/// avisar cuando entran al canal que se está mirando (una vez por canal).
class FriendsRoster {
  List<FriendInfo> _friends = [];
  final Set<String> _notifiedInChannel = {};

  List<FriendInfo> get friends => List.unmodifiable(_friends);

  /// Reemplaza la lista completa (respuesta del servidor).
  void replace(List<FriendInfo> friends) => _friends = List.of(friends);

  /// Inserta o reemplaza un amigo y reordena.
  void upsert(FriendInfo friend) {
    _friends = [
      ..._friends.where((f) => f.deviceId != friend.deviceId),
      friend,
    ];
    _sort();
  }

  void remove(String deviceId) =>
      _friends = _friends.where((f) => f.deviceId != deviceId).toList();

  /// Al cambiar de canal se vuelve a avisar de cero.
  void resetNotified() => _notifiedInChannel.clear();

  /// Aplica la presencia activa de Realtime. `true` si cambió algo visible.
  bool applyPresences(List<Map<String, dynamic>> activePresences) {
    final byDevice = <String, Map<String, dynamic>>{};
    for (final p in activePresences) {
      final devId = p['device_id'] as String?;
      if (devId != null && devId.isNotEmpty) byDevice[devId] = p;
    }

    var changed = false;
    for (var i = 0; i < _friends.length; i++) {
      final friend = _friends[i];
      final presence = byDevice[friend.deviceId];
      if (presence != null) {
        final updated = _withLive(
          friend,
          isOnline: true,
          nickname: presence['nickname'] as String?,
          userCode: presence['user_code'] as String?,
          lastSeen: DateTime.now(),
          channelId: presence['channel_id'] as String?,
          channelName: presence['channel_name'] as String?,
        );
        if (_hasVisibleChange(friend, updated)) {
          _friends[i] = updated;
          changed = true;
        }
      } else if (friend.isOnline || friend.currentChannelId != null) {
        _friends[i] = _withLive(
          friend,
          isOnline: false,
          lastSeen: friend.lastSeen,
        );
        changed = true;
      }
    }
    if (changed) _sort();
    return changed;
  }

  /// Aplica un cambio de la tabla de dispositivos a un amigo.
  ///
  /// Devuelve `null` si el dispositivo no es amigo. Si lo es, devuelve el
  /// nombre a avisar cuando entró al canal [channelId]/[channelName] y aún no
  /// se le avisó, o una cadena vacía si solo cambió la lista.
  String? applyDeviceRecord(
    Map<String, dynamic> record, {
    String? channelId,
    String? channelName,
  }) {
    final deviceId = record['device_id'] as String?;
    final index = _friends.indexWhere((f) => f.deviceId == deviceId);
    if (deviceId == null || index == -1) return null;

    final old = _friends[index];
    final updated = _withLive(
      old,
      isOnline: record['online'] as bool? ?? old.isOnline,
      nickname: record['nickname'] as String?,
      userCode: record['user_code'] as String?,
      lastSeen: record['last_seen'] != null
          ? DateTime.tryParse(record['last_seen'].toString())?.toLocal()
          : old.lastSeen,
      channelId: record['current_channel_id'] as String?,
      channelName: record['current_channel_name'] as String?,
    );
    _friends[index] = updated;
    _sort();

    final wasWatching = old.isWatchingSameChannel(channelId, channelName);
    final isWatching = updated.isWatchingSameChannel(channelId, channelName);
    if (!isWatching) {
      _notifiedInChannel.remove(deviceId);
    } else if (!wasWatching && _notifiedInChannel.add(deviceId)) {
      return updated.nickname ?? updated.userCode;
    }
    return '';
  }

  /// Nombres de los amigos que están en el canal y todavía no se avisaron.
  /// Los que ya no están dejan de contar como avisados.
  List<String> takeNewWatchers(String? channelId, String? channelName) {
    if (channelId == null || channelId.isEmpty) return const [];
    final names = <String>[];
    for (final friend in _friends) {
      if (friend.isWatchingSameChannel(channelId, channelName)) {
        if (_notifiedInChannel.add(friend.deviceId)) {
          names.add(friend.nickname ?? friend.userCode);
        }
      } else {
        _notifiedInChannel.remove(friend.deviceId);
      }
    }
    return names;
  }

  /// Amigos mirando el canal dado.
  List<FriendInfo> watching(String? channelId, String? channelName) {
    if (channelId == null || channelId.isEmpty) return const [];
    return _friends
        .where((f) => f.isWatchingSameChannel(channelId, channelName))
        .toList();
  }

  /// Copia con estado en vivo. A diferencia de `copyWith`, un canal `null`
  /// lo borra: el amigo dejó de mirar.
  static FriendInfo _withLive(
    FriendInfo f, {
    required bool isOnline,
    String? nickname,
    String? userCode,
    DateTime? lastSeen,
    String? channelId,
    String? channelName,
  }) => FriendInfo(
    deviceId: f.deviceId,
    userCode: userCode ?? f.userCode,
    nickname: nickname ?? f.nickname,
    isOnline: isOnline,
    lastSeen: lastSeen,
    currentChannelId: channelId,
    currentChannelName: channelName,
  );

  static bool _hasVisibleChange(FriendInfo a, FriendInfo b) =>
      a.isOnline != b.isOnline ||
      a.currentChannelId != b.currentChannelId ||
      a.currentChannelName != b.currentChannelName ||
      a.nickname != b.nickname;

  void _sort() {
    _friends.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      final nameA = a.nickname ?? a.userCode;
      final nameB = b.nickname ?? b.userCode;
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
  }
}
