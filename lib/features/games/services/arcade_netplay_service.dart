import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/games/services/arcade_webrtc_transport.dart';

/// Señalización (Supabase) + transporte de inputs (WebRTC DataChannel).
class ArcadeNetplayService extends ChangeNotifier {
  static final ArcadeNetplayService instance = ArcadeNetplayService._internal();

  ArcadeNetplayService._internal();

  static const String _globalChannelName = 'arcade_netplay_global';
  static const Duration _inviteTimeout = Duration(seconds: 30);
  static const Duration _iceTimeout = Duration(seconds: 20);

  SupabaseClient? _client;
  RealtimeChannel? _globalChannel;
  RealtimeChannel? _sessionChannel;
  Completer<void>? _sessionSubscribed;

  ArcadeNetplaySession? _currentSession;
  ArcadeNetplayInvite? _pendingIncomingInvite;
  ArcadeRomManagerService? _romManager;

  Timer? _inviteTimer;
  Timer? _heartbeatTimer;
  Timer? _iceTimer;

  ArcadeWebRtcTransport? _webrtc;
  StreamSubscription? _webrtcInputSub;
  StreamSubscription? _webrtcSignalSub;
  StreamSubscription? _webrtcStateSub;

  final StreamController<ArcadeNetplayInputPacket> _remoteInputController =
      StreamController<ArcadeNetplayInputPacket>.broadcast();
  final StreamController<ArcadeNetplayInvite> _inviteStreamController =
      StreamController<ArcadeNetplayInvite>.broadcast();

  /// Paquetes remotos con frame (WebRTC).
  Stream<ArcadeNetplayInputPacket> get onRemoteInputPacket =>
      _remoteInputController.stream;

  Stream<ArcadeNetplayInvite> get onIncomingInvite =>
      _inviteStreamController.stream;

  ArcadeNetplaySession? get currentSession => _currentSession;
  bool get hasActiveSession =>
      _currentSession != null &&
      _currentSession!.status != ArcadeNetplayStatus.idle &&
      _currentSession!.status != ArcadeNetplayStatus.terminated;

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
            _handleIncomingInvite(
              ArcadeNetplayInvite.fromMap(payload),
              myDeviceId,
            );
          }
        },
      );

      _globalChannel!.onBroadcast(
        event: 'invite_response',
        callback: (payload) {
          final target = payload['hostDeviceId'] as String?;
          if (target == myDeviceId &&
              _currentSession != null &&
              _currentSession!.isHost) {
            final accepted = payload['accepted'] as bool? ?? false;
            final busy = payload['busy'] as bool? ?? false;
            final sessionId = payload['sessionId'] as String?;
            if (_currentSession!.sessionId == sessionId) {
              _handleInviteResponse(accepted, busy: busy);
            }
          }
        },
      );

      _globalChannel!.subscribe();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeNetplayService] Error canal global: $e');
      }
    }
  }

  bool _playing = false;

  /// Lo marca [ArcadeScreen] mientras hay un juego en pantalla: las invitaciones
  /// que lleguen se responden "ocupado" sin interrumpir (SPEC-50 D-1).
  void setPlaying(bool playing) => _playing = playing;

  void _handleIncomingInvite(ArcadeNetplayInvite invite, String myDeviceId) {
    if (hasActiveSession || _playing) {
      unawaited(_sendInviteResponse(
        invite,
        myDeviceId: myDeviceId,
        accepted: false,
        busy: true,
      ).catchError((Object e) {
        debugPrint('[ArcadeNetplayService] Error al responder ocupado: $e');
      }));
      return;
    }
    _pendingIncomingInvite = invite;
    _inviteStreamController.add(invite);
    notifyListeners();
  }

  void _handleInviteResponse(bool accepted, {bool busy = false}) {
    _inviteTimer?.cancel();
    _inviteTimer = null;
    if (_currentSession == null) return;

    if (accepted) {
      _currentSession!.status = ArcadeNetplayStatus.preparingRoms;
      _currentSession!.peerStatusText = 'arcade_preparing_game'.tr();
      notifyListeners();
      final romManager = _romManager;
      unawaited(() async {
        await _connectSessionChannel();
        if (romManager != null) {
          await startRomPreparation(romManager);
        }
      }());
    } else {
      _currentSession!.status = ArcadeNetplayStatus.terminated;
      _currentSession!.exitReason =
          (busy ? 'arcade_invite_busy' : 'arcade_invite_rejected').tr();
      notifyListeners();
      unawaited(_cleanupSession());
    }
  }

  Future<bool> inviteFriend({
    required String myDeviceId,
    required String myNickname,
    required String peerDeviceId,
    required String peerNickname,
    required ArcadeRomItem rom,
    required ArcadeRomManagerService romManager,
  }) async {
    await cancelSession(reason: 'arcade_invite_replaced'.tr());

    if (_globalChannel == null) {
      if (kDebugMode) {
        debugPrint('[ArcadeNetplayService] inviteFriend: sin canal global');
      }
      return false;
    }

    _romManager = romManager;
    final sessionId =
        'arcade_${DateTime.now().millisecondsSinceEpoch}_$myDeviceId';
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
      myStatusText: 'arcade_verifying_local'.tr(),
      peerStatusText: 'arcade_waiting_response'.tr(),
    );
    notifyListeners();

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

      await _globalChannel!.sendBroadcastMessage(
        event: 'invite',
        payload: invite.toMap(),
      );

      _inviteTimer?.cancel();
      _inviteTimer = Timer(_inviteTimeout, () {
        if (_currentSession != null &&
            _currentSession!.status == ArcadeNetplayStatus.inviting) {
          _currentSession!.status = ArcadeNetplayStatus.terminated;
          _currentSession!.exitReason = 'arcade_invite_timeout'.tr();
          notifyListeners();
          unawaited(_cleanupSession());
        }
      });

      return true;
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason =
          'arcade_invite_send_error'.tr(namedArgs: {'error': '$e'});
      notifyListeners();
      await _cleanupSession();
      return false;
    }
  }

  Future<void> acceptIncomingInvite({
    required String myDeviceId,
    required String myNickname,
    required ArcadeRomManagerService romManager,
  }) async {
    final invite = _pendingIncomingInvite;
    if (invite == null) return;
    _pendingIncomingInvite = null;
    _romManager = romManager;

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
      myStatusText: 'arcade_verifying_local'.tr(),
      peerStatusText: 'arcade_connecting'.tr(),
    );
    notifyListeners();

    try {
      await _sendInviteResponse(invite, myDeviceId: myDeviceId, accepted: true);
      await _connectSessionChannel();
      await startRomPreparation(romManager);
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason =
          'arcade_invite_accept_error'.tr(namedArgs: {'error': '$e'});
      notifyListeners();
      await _cleanupSession();
    }
  }

  Future<void> rejectIncomingInvite(String myDeviceId) async {
    final invite = _pendingIncomingInvite;
    _pendingIncomingInvite = null;
    notifyListeners();
    if (invite == null) return;
    try {
      await _sendInviteResponse(invite, myDeviceId: myDeviceId, accepted: false);
    } catch (e) {
      debugPrint('[ArcadeNetplayService] Error al rechazar invitación: $e');
    }
  }

  Future<void> _sendInviteResponse(
    ArcadeNetplayInvite invite, {
    required String myDeviceId,
    required bool accepted,
    bool busy = false,
  }) async {
    await _globalChannel?.sendBroadcastMessage(
      event: 'invite_response',
      payload: {
        'sessionId': invite.sessionId,
        'hostDeviceId': invite.hostDeviceId,
        'guestDeviceId': myDeviceId,
        'accepted': accepted,
        if (busy) 'busy': true,
      },
    );
  }

  Future<void> _connectSessionChannel() async {
    final session = _currentSession;
    if (session == null || _client == null) return;

    try {
      await _sessionChannel?.unsubscribe();
      final channelName = 'arcade_session_${session.sessionId}';
      _sessionChannel = _client!.channel(channelName);
      _sessionSubscribed = Completer<void>();

      _sessionChannel!.onBroadcast(
        event: 'rom_prep',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            session.peerProgress =
                (payload['progress'] as num?)?.toDouble() ?? 0.0;
            session.peerStatusText = payload['statusText'] as String? ?? '';
            unawaited(_checkIfBothReady());
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
            session.peerStatusText = 'arcade_game_ready'.tr();
            unawaited(_checkIfBothReady());
            notifyListeners();
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'webrtc_offer',
        callback: (payload) {
          if (payload['senderDeviceId'] == session.peerDeviceId) {
            unawaited(_webrtc?.handleRemoteSignal({
              'type': 'webrtc_offer',
              'sdp': payload['sdp'],
              'sdpType': payload['sdpType'],
            }));
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'webrtc_answer',
        callback: (payload) {
          if (payload['senderDeviceId'] == session.peerDeviceId) {
            unawaited(_webrtc?.handleRemoteSignal({
              'type': 'webrtc_answer',
              'sdp': payload['sdp'],
              'sdpType': payload['sdpType'],
            }));
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'webrtc_ice',
        callback: (payload) {
          if (payload['senderDeviceId'] == session.peerDeviceId) {
            unawaited(_webrtc?.handleRemoteSignal({
              'type': 'webrtc_ice',
              'candidate': payload['candidate'],
              'sdpMid': payload['sdpMid'],
              'sdpMLineIndex': payload['sdpMLineIndex'],
            }));
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'cancel',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            final reason =
                payload['reason'] as String? ?? 'arcade_peer_canceled'.tr();
            session.status = ArcadeNetplayStatus.terminated;
            session.exitReason = reason;
            notifyListeners();
            unawaited(_cleanupSession());
          }
        },
      );

      _sessionChannel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!(_sessionSubscribed?.isCompleted ?? true)) {
            _sessionSubscribed!.complete();
          }
        } else if (status == RealtimeSubscribeStatus.channelError ||
            status == RealtimeSubscribeStatus.timedOut) {
          if (!(_sessionSubscribed?.isCompleted ?? true)) {
            _sessionSubscribed!.completeError(
              error ?? Exception('session subscribe failed'),
            );
          }
        }
      });

      await _sessionSubscribed!.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeNetplayService] Error canal sesión: $e');
      }
    }
  }

  Future<void> startRomPreparation(ArcadeRomManagerService romManager) async {
    final session = _currentSession;
    if (session == null) return;
    _romManager = romManager;

    session.status = ArcadeNetplayStatus.preparingRoms;
    session.myProgress = 0.0;
    session.myStatusText = 'arcade_verifying_local'.tr();
    notifyListeners();

    await _broadcastPrepStatus(0.0, 'arcade_verifying_local'.tr());

    await romManager.refreshInstalledRoms();
    final isInstalled = romManager.installedRoms.any(
      (r) => r.filename.toLowerCase() == session.romFilename.toLowerCase(),
    );

    if (isInstalled) {
      await romManager.setActiveRom(session.romFilename);
      session.myProgress = 1.0;
      session.myStatusText = 'arcade_game_ready'.tr();
      notifyListeners();
      await _broadcastReady();
      await _checkIfBothReady();
      return;
    }

    session.myStatusText =
        'arcade_downloading_game'.tr(namedArgs: {'percent': '0'});
    notifyListeners();
    await _broadcastPrepStatus(
      0.0,
      'arcade_downloading_short'.tr(namedArgs: {'percent': '0'}),
    );

    final item = romManager.catalog.firstWhere(
      (c) => c.filename.toLowerCase() == session.romFilename.toLowerCase(),
      orElse: () => ArcadeRomItem(
        id: session.romFilename,
        name: session.romName,
        filename: session.romFilename,
        url: session.romUrl,
      ),
    );

    try {
      final success = await romManager.downloadRom(
        item,
        onProgress: (progress) {
          session.myProgress = progress;
          final percent = (progress * 100).toInt();
          session.myStatusText = 'arcade_downloading_game'
              .tr(namedArgs: {'percent': '$percent'});
          notifyListeners();
          unawaited(_broadcastPrepStatus(
            progress,
            'arcade_downloading_short'.tr(namedArgs: {'percent': '$percent'}),
          ));
        },
      );

      if (success) {
        await romManager.setActiveRom(session.romFilename);
        session.myProgress = 1.0;
        session.myStatusText = 'arcade_game_ready'.tr();
        notifyListeners();
        await _broadcastReady();
        await _checkIfBothReady();
      } else {
        throw Exception('arcade_rom_download_failed'.tr());
      }
    } catch (e) {
      session.status = ArcadeNetplayStatus.terminated;
      session.exitReason =
          'arcade_netplay_error_rom'.tr(namedArgs: {'error': '$e'});
      notifyListeners();
      await _broadcastCancel('arcade_netplay_error_rom_broadcast'.tr());
      await _cleanupSession();
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
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
  }

  Future<void> _broadcastReady() async {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    try {
      await _sessionChannel!.sendBroadcastMessage(
        event: 'ready_to_play',
        payload: {'senderDeviceId': session.myDeviceId},
      );
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
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
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
  }

  Future<void> _broadcastWebrtcSignal(Map<String, dynamic> signal) async {
    final session = _currentSession;
    if (session == null || _sessionChannel == null) return;
    final type = signal['type'] as String?;
    if (type == null) return;
    try {
      await _sessionChannel!.sendBroadcastMessage(
        event: type,
        payload: {
          'senderDeviceId': session.myDeviceId,
          ...signal,
        },
      );
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
  }

  Future<void> _checkIfBothReady() async {
    final session = _currentSession;
    if (session == null) return;
    if (session.myProgress < 1.0 || session.peerProgress < 1.0) return;
    if (session.status == ArcadeNetplayStatus.ready ||
        session.status == ArcadeNetplayStatus.inGame) {
      return;
    }

    session.status = ArcadeNetplayStatus.ready;
    session.myStatusText = 'arcade_netplay_connecting_p2p'.tr();
    session.peerStatusText = 'arcade_peer_ready'.tr();
    notifyListeners();

    await _startWebRtcHandshake();
  }

  Future<void> _startWebRtcHandshake() async {
    final session = _currentSession;
    if (session == null) return;

    await _disposeWebRtc();
    final transport = ArcadeWebRtcTransport();
    _webrtc = transport;

    _webrtcSignalSub = transport.onSignalOut.listen((signal) {
      unawaited(_broadcastWebrtcSignal(signal));
    });

    _webrtcInputSub = transport.onInput.listen((packet) {
      if (!_remoteInputController.isClosed) {
        _remoteInputController.add(packet);
      }
    });

    _webrtcStateSub = transport.onState.listen((state) {
      if (state == 'connected') {
        _iceTimer?.cancel();
        _iceTimer = null;
        session.status = ArcadeNetplayStatus.inGame;
        session.myStatusText = 'arcade_netplay_ready_both'.tr();
        notifyListeners();
        _startHeartbeat();
        if (session.isHost) {
          transport.sendNetplayStart();
        }
      } else if (state == 'ice_failed') {
        _failIce('arcade_netplay_ice_failed'.tr());
      } else if (state.startsWith('error:')) {
        _failIce('arcade_netplay_webrtc_error'
            .tr(namedArgs: {'error': state.substring(6)}));
      }
    });

    _iceTimer?.cancel();
    _iceTimer = Timer(_iceTimeout, () {
      if (_currentSession?.status == ArcadeNetplayStatus.ready &&
          !(_webrtc?.isConnected ?? false)) {
        _failIce('arcade_netplay_ice_timeout'.tr());
      }
    });

    try {
      if (session.isHost) {
        await transport.startAsHost();
      } else {
        await transport.startAsGuest();
      }
    } catch (e) {
      _failIce(
        'arcade_netplay_webrtc_error'.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  void _failIce(String reason) {
    final session = _currentSession;
    if (session == null) return;
    session.status = ArcadeNetplayStatus.terminated;
    session.exitReason = reason;
    notifyListeners();
    unawaited(_broadcastCancel(reason));
    unawaited(_cleanupSession());
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final session = _currentSession;
      final transport = _webrtc;
      if (session == null || transport == null || !transport.isConnected) {
        if (session != null &&
            session.status == ArcadeNetplayStatus.inGame) {
          session.status = ArcadeNetplayStatus.reconnecting;
          notifyListeners();
        }
        return;
      }
      if (session.status == ArcadeNetplayStatus.reconnecting) {
        session.status = ArcadeNetplayStatus.inGame;
        notifyListeners();
      }
      // Keepalive: máscara 0 en frame -1 no aplica; el propio DC basta.
    });
  }

  /// Envía input local con número de frame por WebRTC.
  void sendLocalInput(int mask, {int frame = 0}) {
    final session = _currentSession;
    final transport = _webrtc;
    if (session == null || transport == null) return;
    transport.sendInput(
      ArcadeNetplayInputPacket(
        frame: frame,
        mask: mask,
        senderDeviceId: session.myDeviceId,
      ),
    );
  }

  Future<void> cancelSession({String? reason}) async {
    final msg = reason ?? 'arcade_netplay_canceled'.tr();
    if (_currentSession != null) {
      await _broadcastCancel(msg);
      _currentSession!.status = ArcadeNetplayStatus.terminated;
      _currentSession!.exitReason = msg;
      notifyListeners();
    }
    await _cleanupSession();
  }

  Future<void> _disposeWebRtc() async {
    await _webrtcInputSub?.cancel();
    await _webrtcSignalSub?.cancel();
    await _webrtcStateSub?.cancel();
    _webrtcInputSub = null;
    _webrtcSignalSub = null;
    _webrtcStateSub = null;
    await _webrtc?.dispose();
    _webrtc = null;
  }

  Future<void> _cleanupSession() async {
    _inviteTimer?.cancel();
    _inviteTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _iceTimer?.cancel();
    _iceTimer = null;

    await _disposeWebRtc();

    try {
      await _sessionChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
    _sessionChannel = null;
    _sessionSubscribed = null;
    _pendingIncomingInvite = null;
    _currentSession = null;
    _romManager = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_cleanupSession());
    try {
      _globalChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[ArcadeNetplayService] $e');
    }
    _globalChannel = null;
    _remoteInputController.close();
    _inviteStreamController.close();
    super.dispose();
  }
}
