import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';

void main() {
  Future<FocusNode> pumpButton(
    WidgetTester tester, {
    required VoidCallback onPressed,
    VoidCallback? onLongPress,
  }) async {
    final node = FocusNode(debugLabel: 'button');
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TvFocusButton(
              focusNode: node,
              label: 'Botón',
              onPressed: onPressed,
              onLongPress: onLongPress,
            ),
          ),
        ),
      ),
    );
    node.requestFocus();
    await tester.pump();
    return node;
  }

  testWidgets('un OK dispara una sola vez (apretar y soltar)', (tester) async {
    var presses = 0;
    await pumpButton(tester, onPressed: () => presses++);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(presses, 1);
  });

  testWidgets('soltar OK que se apretó en otro lado no dispara', (
    tester,
  ) async {
    var presses = 0;
    await pumpButton(tester, onPressed: () => presses++);

    // El foco llegó con OK ya apretado (p. ej. un diálogo que se abrió).
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(presses, 0);
  });

  testWidgets('con pulsación larga, el OK corto dispara al soltar', (
    tester,
  ) async {
    var presses = 0;
    var longPresses = 0;
    await pumpButton(
      tester,
      onPressed: () => presses++,
      onLongPress: () => longPresses++,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    expect(presses, 0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(presses, 1);
    expect(longPresses, 0);
  });

  testWidgets('mantener OK dispara sólo la pulsación larga', (tester) async {
    var presses = 0;
    var longPresses = 0;
    await pumpButton(
      tester,
      onPressed: () => presses++,
      onLongPress: () => longPresses++,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(longPresses, 1);
    expect(presses, 0);
  });
}
