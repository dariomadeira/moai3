import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/services/debug_log_controller.dart';

void main() {
  group('DebugLogController', () {
    tearDown(() {
      AppConfig.debugModeOverride = null;
    });

    test('no acumula entradas si debug está desactivado', () {
      AppConfig.debugModeOverride = false;
      final log = DebugLogController();
      log.logInfo('test');
      log.logWarn('warn');
      log.logError('error');
      expect(log.entries, isEmpty);
    });

    test('acumula entradas y respeta límite circular', () {
      AppConfig.debugModeOverride = true;
      final log = DebugLogController();
      for (var i = 0; i < DebugLogController.maxEntries + 10; i++) {
        log.logInfo('evento $i');
      }
      expect(log.entries.length, DebugLogController.maxEntries);
      expect(log.entries.first.message, contains('10'));
      expect(log.entries.last.message, contains('209'));
    });
  });
}

