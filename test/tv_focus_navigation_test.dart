import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/focus/tv_shortcuts.dart';
import 'package:moai3/widgets/player/tv_viewer_focus_wrapper.dart';

void main() {
  group('flechas sin destino', () {
    late FocusNode left;
    late FocusNode right;

    setUp(() {
      left = FocusNode();
      right = FocusNode();
    });

    tearDown(() {
      left.dispose();
      right.dispose();
    });

    Future<void> pump(WidgetTester tester, {required bool blocked}) async {
      final row = Row(
        children: [
          Focus(focusNode: left, child: const SizedBox(width: 50, height: 50)),
          Focus(focusNode: right, child: const SizedBox(width: 50, height: 50)),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Shortcuts(
            shortcuts: TvShortcuts.dpad,
            child: blocked
                ? Actions(actions: TvShortcuts.noGeometricFocus, child: row)
                : row,
          ),
        ),
      );
      left.requestFocus();
      await tester.pump();
    }

    testWidgets('sin el bloqueo, Flutter mueve el foco por geometría', (
      tester,
    ) async {
      await pump(tester, blocked: false);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(right.hasPrimaryFocus, isTrue);
    });

    testWidgets('con el bloqueo el foco se queda donde está', (tester) async {
      await pump(tester, blocked: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(left.hasPrimaryFocus, isTrue);
    });
  });

  testWidgets('↓ desde el visor pide bajar a Favoritos', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    var down = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TvViewerFocusWrapper(
          focusNode: node,
          effectiveFullScreen: false,
          onRequestDownFocus: () => down++,
          child: const SizedBox(width: 50, height: 50),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);

    expect(down, 1);
  });
}
