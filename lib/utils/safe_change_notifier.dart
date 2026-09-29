import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Evita `notifyListeners()` durante la fase de build del framework.
mixin SafeChangeNotifier on ChangeNotifier {
  bool _isNotifierDisposed = false;

  @override
  void dispose() {
    _isNotifierDisposed = true;
    super.dispose();
  }

  void safeNotifyListeners() {
    if (_isNotifierDisposed) return;
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        notifyListeners();
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_isNotifierDisposed) {
          try {
            if (hasListeners) notifyListeners();
          } catch (_) {}
        }
      });
    } catch (_) {
      if (!_isNotifierDisposed) {
        try {
          notifyListeners();
        } catch (_) {}
      }
    }
  }
}

