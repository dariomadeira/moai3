import 'package:flutter/material.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

/// Tracks the 16:9 placeholder bounds and fullscreen state for the TV player overlay.
class PlayerOverlayController extends ChangeNotifier with SafeChangeNotifier {
  final GlobalKey placeholderKey = GlobalKey();
  Rect smallPlayerRect = Rect.zero;
  bool pendingInitialFocus = true;
  bool isFullScreen = false;
  DateTime? lastExitFullScreenTime;
  int _measureRetries = 0;

  void updatePlaceholderRect({bool retryIfInvalid = false}) {
    final context = placeholderKey.currentContext;
    if (context == null) {
      if (retryIfInvalid) _scheduleRetry();
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      if (retryIfInvalid) _scheduleRetry();
      return;
    }

    final size = renderObject.size;
    if (size.width <= 0 || size.height <= 0) {
      if (retryIfInvalid) _scheduleRetry();
      return;
    }

    final rect = renderObject.localToGlobal(Offset.zero) & size;
    _measureRetries = 0;
    if (smallPlayerRect != rect) {
      smallPlayerRect = rect;
      safeNotifyListeners();
    }
  }

  void _scheduleRetry() {
    if (_measureRetries >= 12) return;
    _measureRetries++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updatePlaceholderRect(retryIfInvalid: true);
    });
  }

  bool get hasValidRect => smallPlayerRect.width > 0;

  void setFullScreen(bool value) {
    if (isFullScreen == value) return;
    isFullScreen = value;
    if (!value) {
      lastExitFullScreenTime = DateTime.now();
    }
    safeNotifyListeners();
  }

  void markInitialFocusDone() {
    pendingInitialFocus = false;
  }

  bool shouldRequestInitialFocus(bool isLoadingChannels) {
    return pendingInitialFocus && !isLoadingChannels && hasValidRect;
  }
}

