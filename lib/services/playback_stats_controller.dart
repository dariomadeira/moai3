import 'package:flutter/foundation.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

enum PlaybackHealth { idle, playing, buffering, reconnecting, error }

enum PlayerBackend { none, engineKotlin }

typedef PlayerStatsSnapshot = ({
  PlayerBackend backend,
  PlaybackHealth status,
});

/// Estado del reproductor para el panel de debug y el selector de servidor.
class PlaybackStatsController extends ChangeNotifier with SafeChangeNotifier {
  PlaybackHealth _status = PlaybackHealth.idle;
  PlayerBackend _backend = PlayerBackend.none;
  int _fallbackIndex = 0;

  PlaybackHealth get status => _status;
  PlayerBackend get backend => _backend;
  int get fallbackIndex => _fallbackIndex;

  PlayerStatsSnapshot get snapshot => (backend: _backend, status: _status);

  void setBackend(PlayerBackend backend) {
    if (_backend == backend) return;
    _backend = backend;
    _status = backend == PlayerBackend.none
        ? PlaybackHealth.idle
        : PlaybackHealth.buffering;
    safeNotifyListeners();
  }

  void setFallbackIndex(int index) {
    if (_fallbackIndex != index) {
      _fallbackIndex = index;
      safeNotifyListeners();
    }
  }

  void setPlaying() => _setUnlessFailing(PlaybackHealth.playing);

  void setBuffering() => _setUnlessFailing(PlaybackHealth.buffering);

  void setError() {
    _status = PlaybackHealth.error;
    safeNotifyListeners();
  }

  void setReconnecting() {
    _status = PlaybackHealth.reconnecting;
    safeNotifyListeners();
  }

  /// Un error o una reconexión en curso no se pisan con playing/buffering.
  void _setUnlessFailing(PlaybackHealth next) {
    if (_status == PlaybackHealth.error ||
        _status == PlaybackHealth.reconnecting ||
        _status == next) {
      return;
    }
    _status = next;
    safeNotifyListeners();
  }
}
