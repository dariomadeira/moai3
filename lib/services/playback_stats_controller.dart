import 'package:flutter/foundation.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

enum PlaybackHealth { idle, playing, buffering, reconnecting, error }

enum PlayerBackend {
  none,
  engineKotlin,
  legacyVideoPlayer,
  youtube,
}

typedef PlayerStatsSnapshot = ({
  PlayerBackend backend,
  double? bitrateMbps,
  int bufferAheadSec,
  double bufferingPercent,
  PlaybackHealth status,
});

class PlaybackStatsController extends ChangeNotifier with SafeChangeNotifier {
  double? _bitrateMbps;
  int _bufferAheadSec = 0;
  double _bufferingPercent = 0;
  PlaybackHealth _status = PlaybackHealth.idle;
  PlayerBackend _backend = PlayerBackend.none;
  int _videoWidth = 0;
  int _fallbackIndex = 0;
  bool _lastBuffering = false;

  double? get bitrateMbps => _bitrateMbps;
  int get bufferAheadSec => _bufferAheadSec;
  double get bufferingPercent => _bufferingPercent;
  PlaybackHealth get status => _status;
  PlayerBackend get backend => _backend;
  int get fallbackIndex => _fallbackIndex;
  bool get hasVideoFrame => _videoWidth > 0;
  bool get showLoadingOverlay {
    if (_status == PlaybackHealth.playing || _status == PlaybackHealth.idle) {
      return false;
    }
    return _lastBuffering || !hasVideoFrame;
  }

  bool get showsMediaKitStats => false;

  PlayerStatsSnapshot get snapshot => (
        backend: _backend,
        bitrateMbps: _bitrateMbps,
        bufferAheadSec: _bufferAheadSec,
        bufferingPercent: _bufferingPercent,
        status: _status,
      );

  void setBackend(PlayerBackend backend) {
    if (_backend == backend) return;
    _backend = backend;
    _bitrateMbps = null;
    _bufferAheadSec = 0;
    _bufferingPercent = 0;
_status = switch (backend) {
      PlayerBackend.none => PlaybackHealth.idle,
      PlayerBackend.engineKotlin => PlaybackHealth.buffering,
      PlayerBackend.legacyVideoPlayer => PlaybackHealth.buffering,
      PlayerBackend.youtube => PlaybackHealth.idle,
    };
    safeNotifyListeners();
  }

  void setBitrateMbps(double? mbps) {
    if (_bitrateMbps != mbps) {
      _bitrateMbps = mbps;
      safeNotifyListeners();
    }
  }

  void setFallbackIndex(int index) {
    if (_fallbackIndex != index) {
      _fallbackIndex = index;
      safeNotifyListeners();
    }
  }

  void setVideoWidth(int width) {
    if (_videoWidth != width) {
      _videoWidth = width;
      safeNotifyListeners();
    }
  }

  void setPlaying() {
    if (_status != PlaybackHealth.error &&
        _status != PlaybackHealth.reconnecting) {
      _status = PlaybackHealth.playing;
      _lastBuffering = false;
      safeNotifyListeners();
    }
  }

  void setBuffering() {
    if (_status != PlaybackHealth.error &&
        _status != PlaybackHealth.reconnecting) {
      _status = PlaybackHealth.buffering;
      _lastBuffering = true;
      safeNotifyListeners();
    }
  }

  void setIdle() {
    if (_status != PlaybackHealth.error &&
        _status != PlaybackHealth.reconnecting) {
      _status = PlaybackHealth.idle;
      safeNotifyListeners();
    }
  }

  void setError() {
    _status = PlaybackHealth.error;
    safeNotifyListeners();
  }

  void setReconnecting() {
    _status = PlaybackHealth.reconnecting;
    safeNotifyListeners();
  }

  void detach({bool notify = true}) {
    _bitrateMbps = null;
    _bufferAheadSec = 0;
    _bufferingPercent = 0;
    _videoWidth = 0;
    _status = PlaybackHealth.idle;
    _backend = PlayerBackend.none;
    _lastBuffering = false;
    if (notify) safeNotifyListeners();
  }

  void reset() {
    detach(notify: true);
  }
}

