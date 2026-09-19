import 'package:flutter/foundation.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

enum DebugLogLevel { info, warn, error }

class DebugLogEntry {
  final DateTime time;
  final DebugLogLevel level;
  final String message;

  const DebugLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });
}

class DebugLogController extends ChangeNotifier with SafeChangeNotifier {
  static const int maxEntries = 200;

  final List<DebugLogEntry> entries = [];

  void logInfo(String message) => _add(DebugLogLevel.info, message);

  void logWarn(String message) => _add(DebugLogLevel.warn, message);

  void logError(String message) => _add(DebugLogLevel.error, message);

  void _add(DebugLogLevel level, String message) {
    if (!AppConfig.debugMode) return;
    entries.add(DebugLogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
    ));
    while (entries.length > maxEntries) {
      entries.removeAt(0);
    }
    safeNotifyListeners();
  }
}

