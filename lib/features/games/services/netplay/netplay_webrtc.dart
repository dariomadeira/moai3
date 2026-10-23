part of '../arcade_netplay_service.dart';

/// Handshake WebRTC, fallas de ICE y heartbeat de la partida.
extension _NetplayWebRtc on ArcadeNetplayService {
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
        session.myStatusText = LocaleKeys.arcade_netplay_ready_both.tr();
        _notifyChanged();
        _startHeartbeat();
        if (session.isHost) {
          transport.sendNetplayStart();
        }
      } else if (state == 'ice_failed') {
        _failIce(LocaleKeys.arcade_netplay_ice_failed.tr());
      } else if (state.startsWith('error:')) {
        _failIce(LocaleKeys.arcade_netplay_webrtc_error
            .tr(namedArgs: {'error': state.substring(6)}));
      }
    });

    _iceTimer?.cancel();
    _iceTimer = Timer(ArcadeNetplayService._iceTimeout, () {
      if (_currentSession?.status == ArcadeNetplayStatus.ready &&
          !(_webrtc?.isConnected ?? false)) {
        _failIce(LocaleKeys.arcade_netplay_ice_timeout.tr());
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
        LocaleKeys.arcade_netplay_webrtc_error.tr(namedArgs: {'error': '$e'}),
      );
    }
  }

  void _failIce(String reason) {
    final session = _currentSession;
    if (session == null) return;
    session.status = ArcadeNetplayStatus.terminated;
    session.exitReason = reason;
    _notifyChanged();
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
          _notifyChanged();
        }
        return;
      }
      if (session.status == ArcadeNetplayStatus.reconnecting) {
        session.status = ArcadeNetplayStatus.inGame;
        _notifyChanged();
      }
      // Keepalive: máscara 0 en frame -1 no aplica; el propio DC basta.
    });
  }
}
