import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Evita `notifyListeners()` durante la fase de build del framework.
///
/// Los errores de los listeners los reporta `notifyListeners()` con
/// `FlutterError.reportError`; acá no se silencia nada (SPEC-50 §2.9).
mixin SafeChangeNotifier on ChangeNotifier {
  bool _isNotifierDisposed = false;

  @override
  void dispose() {
    _isNotifierDisposed = true;
    super.dispose();
  }

  void safeNotifyListeners() {
    if (_isNotifierDisposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_isNotifierDisposed && hasListeners) notifyListeners();
    });
  }
}
