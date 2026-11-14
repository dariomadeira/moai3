import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/app/bootstrap.dart';
import 'package:moai3/config/app_config.dart';

void main() {
  late DebugPrintCallback original;
  final lines = <String?>[];

  setUp(() {
    original = debugPrint;
    lines.clear();
    debugPrint = (String? message, {int? wrapWidth}) => lines.add(message);
  });

  tearDown(() {
    debugPrint = original;
    AppConfig.debugModeOverride = null;
  });

  test('release sin DEBUG_MODE: debugPrint queda mudo', () {
    AppConfig.debugModeOverride = false;
    AppBootstrap.silenceLogsIfPublished(release: true);
    debugPrint('no se escribe');
    expect(lines, isEmpty);
  });

  test('release con DEBUG_MODE: los logs siguen', () {
    AppConfig.debugModeOverride = true;
    AppBootstrap.silenceLogsIfPublished(release: true);
    debugPrint('se escribe');
    expect(lines, ['se escribe']);
  });

  test('debug: los logs siguen aunque DEBUG_MODE esté apagado', () {
    AppConfig.debugModeOverride = false;
    // Los tests corren en debug.
    AppBootstrap.silenceLogsIfPublished();
    debugPrint('se escribe');
    expect(lines, ['se escribe']);
  });
}
