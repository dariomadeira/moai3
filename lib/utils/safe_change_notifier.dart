import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Evita `notifyListeners()` durante la fase de build del framework.
mixin SafeChangeNotifier on ChangeNotifier {
  void safeNotifyListeners() {
    try {
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.idle ||
          phase == SchedulerPhase.postFrameCallbacks) {
        notifyListeners();
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) notifyListeners();
      });
    } catch (_) {
      notifyListeners();
    }
  }
}

