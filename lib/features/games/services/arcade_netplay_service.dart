import 'dart:async';

import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/games/services/arcade_webrtc_transport.dart';

part 'netplay/netplay_session_channel.dart';
part 'netplay/netplay_broadcasts.dart';
part 'netplay/netplay_webrtc.dart';

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
      _currentSession!.peerStatusText = LocaleKeys.arcade_preparing_game.tr();
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
          (busy ? LocaleKeys.arcade_invite_busy : LocaleKeys.arcade_invite_rejected).tr();
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
    await cancelSession(reason: LocaleKeys.arcade_invite_replaced.tr());

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
      myStatusText: LocaleKeys.arcade_verifying_local.tr(),
      peerStatusText: LocaleKeys.arcade_waiting_response.tr(),
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
          _currentSession!.exitReason = LocaleKeys.arcade_invite_timeout.tr();
          notifyListeners();
          unawaited(_cleanupSession());
        }
      });

      return true;
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason =
          LocaleKeys.arcade_invite_send_error.tr(namedArgs: {'error': '$e'});
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
      myStatusText: LocaleKeys.arcade_verifying_local.tr(),
      peerStatusText: LocaleKeys.arcade_connecting.tr(),
    );
    notifyListeners();

    try {
      await _sendInviteResponse(invite, myDeviceId: myDeviceId, accepted: true);
      await _connectSessionChannel();
      await startRomPreparation(romManager);
    } catch (e) {
      _currentSession?.status = ArcadeNetplayStatus.terminated;
      _currentSession?.exitReason =
          LocaleKeys.arcade_invite_accept_error.tr(namedArgs: {'error': '$e'});
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

  Future<void> startRomPreparation(ArcadeRomManagerService romManager) async {
    final session = _currentSession;
    if (session == null) return;
    _romManager = romManager;

    session.status = ArcadeNetplayStatus.preparingRoms;
    session.myProgress = 0.0;
    session.myStatusText = LocaleKeys.arcade_verifying_local.tr();
    notifyListeners();

    await _broadcastPrepStatus(0.0, LocaleKeys.arcade_verifying_local.tr());

    await romManager.refreshInstalledRoms();
    final isInstalled = romManager.installedRoms.any(
      (r) => r.filename.toLowerCase() == session.romFilename.toLowerCase(),
    );

    if (isInstalled) {
      await romManager.setActiveRom(session.romFilename);
      session.myProgress = 1.0;
      session.myStatusText = LocaleKeys.arcade_game_ready.tr();
      notifyListeners();
      await _broadcastReady();
      await _checkIfBothReady();
      return;
    }

    session.myStatusText =
        LocaleKeys.arcade_downloading_game.tr(namedArgs: {'percent': '0'});
    notifyListeners();
    await _broadcastPrepStatus(
      0.0,
      LocaleKeys.arcade_downloading_short.tr(namedArgs: {'percent': '0'}),
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
          session.myStatusText = LocaleKeys.arcade_downloading_game
              .tr(namedArgs: {'percent': '$percent'});
          notifyListeners();
          unawaited(_broadcastPrepStatus(
            progress,
            LocaleKeys.arcade_downloading_short.tr(namedArgs: {'percent': '$percent'}),
          ));
        },
      );

      if (success) {
        await romManager.setActiveRom(session.romFilename);
        session.myProgress = 1.0;
        session.myStatusText = LocaleKeys.arcade_game_ready.tr();
        notifyListeners();
        await _broadcastReady();
        await _checkIfBothReady();
      } else {
        throw Exception(LocaleKeys.arcade_rom_download_failed.tr());
      }
    } catch (e) {
      session.status = ArcadeNetplayStatus.terminated;
      session.exitReason =
          LocaleKeys.arcade_netplay_error_rom.tr(namedArgs: {'error': '$e'});
      notifyListeners();
      await _broadcastCancel(LocaleKeys.arcade_netplay_error_rom_broadcast.tr());
      await _cleanupSession();
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
    session.myStatusText = LocaleKeys.arcade_netplay_connecting_p2p.tr();
    session.peerStatusText = LocaleKeys.arcade_peer_ready.tr();
    notifyListeners();

    await _startWebRtcHandshake();
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
    final msg = reason ?? LocaleKeys.arcade_netplay_canceled.tr();
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

  /// `notifyListeners` para los `part` (es `@protected`).
  void _notifyChanged() => notifyListeners();

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
