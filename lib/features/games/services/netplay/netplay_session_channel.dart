part of '../arcade_netplay_service.dart';

/// Respuesta a invitaciones y canal Realtime de la sesión con sus eventos.
extension _NetplaySessionChannel on ArcadeNetplayService {
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
            _notifyChanged();
          }
        },
      );

      _sessionChannel!.onBroadcast(
        event: 'ready_to_play',
        callback: (payload) {
          final sender = payload['senderDeviceId'] as String?;
          if (sender == session.peerDeviceId) {
            session.peerProgress = 1.0;
            session.peerStatusText = LocaleKeys.arcade_game_ready.tr();
            unawaited(_checkIfBothReady());
            _notifyChanged();
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
                payload['reason'] as String? ?? LocaleKeys.arcade_peer_canceled.tr();
            session.status = ArcadeNetplayStatus.terminated;
            session.exitReason = reason;
            _notifyChanged();
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
}
