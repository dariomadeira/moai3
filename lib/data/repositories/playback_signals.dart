import 'package:flutter/foundation.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

/// Señales de playback compartidas (reload / skip de servidor / error).
class PlaybackSignals extends ChangeNotifier with SafeChangeNotifier {
  int reloadKey = 0;
  int serverSkipKey = 0;
  bool currentChannelHasError = false;

  void bumpReload() {
    reloadKey++;
    safeNotifyListeners();
  }

  void skipServer() {
    serverSkipKey++;
    safeNotifyListeners();
  }

  void setChannelError(bool hasError) {
    if (currentChannelHasError == hasError) return;
    currentChannelHasError = hasError;
    safeNotifyListeners();
  }
}

