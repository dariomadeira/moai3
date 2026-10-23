part of '../arcade_netplay_service.dart';

/// Mensajes al otro TV por el canal de sesión (preparación, listo, cancelación, señales WebRTC).
extension _NetplayBroadcasts on ArcadeNetplayService {
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
}
