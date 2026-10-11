import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';

/// Servicio singleton que gestiona la señalización, sincronización de ROMs y
/// transmisión de inputs para partidas de Arcade a la distancia (Netplay).
class ArcadeNetplayService extends ChangeNotifier {
  static final ArcadeNetplayService instance = ArcadeNetplayService._internal();

  ArcadeNetplayService._internal();

  static const String _globalChannelName = 'arcade_netplay_global';
  static const Duration _inviteTimeout = Duration(seconds: 30);

  SupabaseClient? _client;
  RealtimeChannel? _globalChannel;
  RealtimeChannel? _sessionChannel;

  ArcadeNetplaySession? _currentSession;
  ArcadeNetplayInvite? _pendingIncomingInvite;

  Timer? _inviteTimer;
  Timer? _heartbeatTimer;

  final StreamController<int> _remoteInputController =
      StreamController<int>.broadcast();
  final StreamController<ArcadeNetplayInvite> _inviteStreamController =
      StreamController<ArcadeNetplayInvite>.broadcast();

  Stream<int> get onRemoteInputReceived => _remoteInputController.stream;
  Stream<ArcadeNetplayInvite> get onIncomingInvite => _inviteStreamController.stream;

  ArcadeNetplaySession? get currentSession => _currentSession;
  ArcadeNetplayInvite? get pendingIncomingInvite => _pendingIncomingInvite;
  bool get hasActiveSession => _currentSession != null &&
      _currentSession!.status != ArcadeNetplayStatus.idle &&
      _currentSession!.status != ArcadeNetplayStatus.terminated;

  /// Inicializa la escucha global de invitaciones mediante Supabase Realtime.
  void initialize({SupabaseClient? client, required String myDeviceId}) {
    _client = client ?? Supabase.instance.client;
    _subscribeGlobal(myDeviceId);
  }

  void _subscribeGlobal(String myDeviceId) {
    if (_globalChannel != null) return;
    try {
      _globalChannel = _client!.channel(_globalChannelName);

      _globalChannel!.onBroadcast(
        event: 'invite',
        callback: (payload) {
          final target = payload['guestDeviceId'] as String?;
          if (target == myDeviceId) {
            _handleIncomingInvite(ArcadeNetplayInvite.fromMap(payload));
          }
        },
      );

      _globalChannel!.onBroadcast(
        event: 'invite_response',
        callback: (payload) {
          final target = payload['hostDeviceId'] as String?;
          if (target == myDeviceId && _currentSession != null && _currentSession!.isHost) {
            final accepted = payload['accepted'] as bool? ?? false;
            final sessionId = payload['sessionId'] as String?;
            if (_currentSession!.sessionId == sessionId) {
              _handleInviteResponse(accepted);
            }
          }
        },
      );

      _globalChannel!.subscribe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeNetplayService] Error suscribiendo a canal global: $e');
      }
    }
  }

  void _handleIncomingInvite(ArcadeNetplayInvite invite) {
    // Si ya estamos en una partida activa, ignorar
    if (hasActiveSession) return;

    _pendingIncomingInvite = invite;
    _inviteStreamController.add(invite);
    notifyListeners();
  }

  void _handleInviteResponse(bool accepted) {
    _inviteTimer?.cancel();
    _inviteTimer = null;

    if (_currentSession == null) return;

    if (accepted) {
      _currentSession!.status = ArcadeNetplayStatus.preparingRoms;
      _currentSession!.peerStatusText = 'Preparando juego...';
      _connectSessionChannel();
      notifyListeners();
    } else {
      _currentSession!.status = ArcadeNetplayStatus.terminated;
      _currentSession!.exitReason = 'El amigo rechazó la invitación';
      notifyListeners();
      _cleanupSession();
    }
  }

  /// Inicia el flujo como Host invitando a un amigo.
  Future<bool> inviteFriend({
    required String myDeviceId,
    required String myNickname,
    required String peerDeviceId,
    required String peerNickname,
    required ArcadeRomItem rom,
    required ArcadeRomManagerService romManager,
  }) async {
    cancelSession(reason: 'Nueva invitación iniciada');

    final sessionId = 'arcade_${DateTime.now().millisecondsSinceEpoch}_$myDeviceId';
    _currentSession = ArcadeNetplaySession(
      sessionId: sessionId,
      isHost: true,
      myDeviceId: myDeviceId,
      myNickname: myNickname,
      peerDeviceId: peerDeviceId,
      peerNickname: peerNickname,
      romFilename: rom.filename,
      romName: rom.name.isNotEmpty ? rom.name : rom.filename,
      romUrl: rom.url,
      status: ArcadeNetplayStatus.inviting,
      myStatusText: 'Verificando archivo local...',
      peerStatusText: 'Esperando respuesta...',
    );

    notifyListeners();

    // 1. Enviar evento broadcast de invitación
    try {
      final invite = ArcadeNetplayInvite(
        sessionId: sessionId,
        hostDeviceId: myDeviceId,
        hostNickname: myNickname,
        guestDeviceId: peerDeviceId,
        romFilename: rom.filename,
        romName: rom.name.isNotEmpty ? rom.name : rom.filename,
        romUrl: rom.url,
      );

      await _globalChannel?.sendBroadcastMessage(
        event: 'invite',
        payload: invite.toMap(),
      );

      // Timer antifallas: 30s de gracia
      _inviteTimer?.cancel();
      _inviteTimer = Timer(_inviteTimeout, () {
        if (_currentSession != null &&
            _currentSession!.status == ArcadeNetplayStatus.inviting) {
          _currentSession!.status = ArcadeNetplayStatus.terminated;
          _currentSession!.exitReason = 'Tiempo de espera agotado (sin respuesta)';
          notifyListeners();
          _cleanupSession();
        }
      });

      return true;
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason = 'Error de red al enviar invitación: $e';
      notifyListeners();
      _cleanupSession();
      return false;
    }
  }

  /// Acepta la invitación entrante y arranca la preparación.
  Future<void> acceptIncomingInvite({
    required String myDeviceId,
    required String myNickname,
    required ArcadeRomManagerService romManager,
  }) async {
    final invite = _pendingIncomingInvite;
    if (invite == null) return;
    _pendingIncomingInvite = null;

    _currentSession = ArcadeNetplaySession(
      sessionId: invite.sessionId,
      isHost: false,
      myDeviceId: myDeviceId,
      myNickname: myNickname,
      peerDeviceId: invite.hostDeviceId,
      peerNickname: invite.hostNickname,
      romFilename: invite.romFilename,
      romName: invite.romName,
      romUrl: invite.romUrl,
      status: ArcadeNetplayStatus.preparingRoms,
      myStatusText: 'Verificando juego...',
      peerStatusText: 'Conectando...',
    );

    notifyListeners();

    try {
      // Responder al Host
      await _globalChannel?.sendBroadcastMessage(
        event: 'invite_response',
        payload: {
          'sessionId': invite.sessionId,
          'hostDeviceId': invite.hostDeviceId,
          'guestDeviceId': myDeviceId,
          'accepted': true,
        },
      );

      _connectSessionChannel();
      startRomPreparation(romManager);
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason = 'Error al aceptar invitación: $e';
      notifyListeners();
      _cleanupSession();
    }
  }

  /// Rechaza la invitación entrante.
  Future<void> rejectIncomingInvite(String myDeviceId) async {
    final invite = _pendingIncomingInvite;
    _pendingIncomingInvite = null;
    notifyListeners();

    if (invite == null) return;

    try {
      await _globalChannel?.sendBroadcastMessage(
        event: 'invite_response',
        payload: {
          'sessionId': invite.sessionId,
          'hostDeviceId': invite.hostDeviceId,
          'guestDeviceId': myDeviceId,
          'accepted': false,
        },
      );
    } catch (_) {}
  }

  void _connectSessionChannel() {
    final session = _currentSession;
    if (session == null || _client == null) return;

    try {
      _sessionChannel?.unsubscribe();
      final channelName = 'arcade_session_${session.sessionId}';
      _sessionChannel = _client!.channel(channelName);

      _sessionChannel!.onBroadcast(
        event: 'rom_prep',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            final progress = (payload['progress'] as num?)?.toDouble() ?? 0.0;
            final statusText = payload['statusText'] as String? ?? '';
            session.peerProgress = progress;
            session.peerStatusText = statusText;
            _checkIfBothReady();
            notifyListeners();
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'ready_to_play',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            session.peerProgress = 1.0;
            session.peerStatusText = 'Juego listo';
            _checkIfBothReady();
            notifyListeners();
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'input',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            final mask = payload['mask'] as int? ?? 0;
            if (!_remoteInputController.isClosed) {
              _remoteInputController.add(mask);
            }
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'cancel',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            final reason = payload['reason'] as String? ?? 'El amigo canceló la partida';
            session.status = ArcadeNetplayStatus.terminated;
            session.exitReason = reason;
            notifyListeners();
            _cleanupSession();
          }
        },
      );

      _sessionChannel!.subscribe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeNetplayService] Error conectando a canal de sesión: $e');
      }
    }
  }

  /// Verifica la ROM local. Si no existe, inicia la descarga y sincroniza el progreso.
  Future<void> startRomPreparation(ArcadeRomManagerService romManager) async {
    final session = _currentSession;
    if (session == null) return;

    session.status = ArcadeNetplayStatus.preparingRoms;
    session.myProgress = 0.0;
    session.myStatusText = 'Verificando archivo local...';
    notifyListeners();

    await _broadcastPrepStatus(0.0, 'Verificando...');

    // 1. Revisar si ya está instalada
    await romManager.refreshInstalledRoms();
    final isInstalled = romManager.installedRoms.any(
      (r) => r.filename.toLowerCase() == session.romFilename.toLowerCase(),
    );

    if (isInstalled) {
      session.myProgress = 1.0;
      session.myStatusText = 'Juego listo';
      notifyListeners();
      await _broadcastReady();
      _checkIfBothReady();
      return;
    }

    // 2. Si no está instalada, descargarla reportando progreso continuo
    session.myStatusText = 'Descargando juego (0%)...';
    notifyListeners();
    await _broadcastPrepStatus(0.0, 'Descargando (0%)...');

    final item = romManager.catalog.firstWhere(
      (c) => c.filename.toLowerCase() == session.romFilename.toLowerCase(),
      orElse: () => ArcadeRomItem(
        id: session.romFilename,
        name: session.romName,
        filename: session.romFilename,
        system: 'CPS-2',
        year: '',
        company: 'Capcom',
        sizeBytes: 0,
        sizeLabel: '',
        url: session.romUrl,
        description: '',
      ),
    );

    try {
      final success = await romManager.downloadRom(
        item,
        onProgress: (progress) {
          session.myProgress = progress;
          final percent = (progress * 100).toInt();
          session.myStatusText = 'Descargando juego ($percent%)...';
          notifyListeners();
          _broadcastPrepStatus(progress, 'Descargando ($percent%)...');
        },
      );

      if (success) {
        session.myProgress = 1.0;
        session.myStatusText = 'Juego listo';
        notifyListeners();
        await _broadcastReady();
        _checkIfBothReady();
      } else {
        throw Exception('Fallo al descargar la ROM');
      }
    } catch (e) {
      session.status = ArcadeNetplayStatus.terminated;
      session.exitReason = 'Error descargando la ROM: $e';
      notifyListeners();
      await _broadcastCancel('Error en descarga de ROM');
      _cleanupSession();
    }
  }

  Future<void> _broadcastPrepStatus(double progress, String statusText) async {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    try {
      await _sessionChannel!.sendBroadcastMessage(
        event: 'rom_prep',
        payload: {
          'senderDeviceId': session.myDeviceId,
          'progress': progress,
          'statusText': statusText,
        },
      );
    } catch (_) {}
  }

  Future<void> _broadcastReady() async {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    try {
      await _sessionChannel!.sendBroadcastMessage(
        event: 'ready_to_play',
        payload: {
          'senderDeviceId': session.myDeviceId,
        },
      );
    } catch (_) {}
  }

  Future<void> _broadcastCancel(String reason) async {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    try {
      await _sessionChannel!.sendBroadcastMessage(
        event: 'cancel',
        payload: {
          'senderDeviceId': session.myDeviceId,
          'reason': reason,
        },
      );
    } catch (_) {}
  }

  void _checkIfBothReady() {
    final session = _currentSession;
    if (session != null &&
        session.myProgress >= 1.0 &&
        session.peerProgress >= 1.0 &&
        session.status != ArcadeNetplayStatus.ready &&
        session.status != ArcadeNetplayStatus.inGame) {
      session.status = ArcadeNetplayStatus.ready;
      session.myStatusText = '¡Ambos listos! Iniciando partida...';
      session.peerStatusText = 'Listo';
      notifyListeners();
    }
  }

  /// Envía la máscara de bits de controles presionados localmente por la red al amigo.
  void sendLocalInput(int mask) {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    try {
      _sessionChannel!.sendBroadcastMessage(
        event: 'input',
        payload: {
          'senderDeviceId': session.myDeviceId,
          'mask': mask,
        },
      );
    } catch (_) {}
  }

  /// Cancela la sesión actual y limpia recursos limpiamente.
  void cancelSession({String? reason}) {
    if (_currentSession != null) {
      _broadcastCancel(reason ?? 'Partida cancelada');
      _currentSession!.status = ArcadeNetplayStatus.terminated;
      _currentSession!.exitReason = reason;
      notifyListeners();
    }
    _cleanupSession();
  }

  void _cleanupSession() {
    _inviteTimer?.cancel();
    _inviteTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    try {
      _sessionChannel?.unsubscribe();
    } catch (_) {}
    _sessionChannel = null;

    _pendingIncomingInvite = null;
    _currentSession = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanupSession();
    try {
      _globalChannel?.unsubscribe();
    } catch (_) {}
    _globalChannel = null;
    _remoteInputController.close();
    _inviteStreamController.close();
    super.dispose();
  }
}
