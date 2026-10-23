import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

void main() {
  late FocusNode node;
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    bool withLongPress = true,
    bool consumeRight = true,
  }) async {
    node = FocusNode();
    calls = [];
    await tester.pumpWidget(
      MaterialApp(
        home: TvPressDetector(
          focusNode: node,
          autofocus: true,
          onPress: () => calls.add('press'),
          onLongPress: withLongPress ? () => calls.add('long') : null,
          onRight: () {
            calls.add('right');
            return consumeRight;
          },
          onDown: () => calls.add('down'),
          child: const SizedBox(width: 10, height: 10),
        ),
      ),
    );
    await tester.pump();
  }

  tearDown(() => node.dispose());

  testWidgets('tap corto dispara onPress al soltar', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    expect(calls, isEmpty);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(calls, ['press']);
  });

  testWidgets('mantener OK dispara solo onLongPress', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(TvTiming.longPress);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(calls, ['long']);
  });

  testWidgets('sin onLongPress, mantener OK igual hace tap', (tester) async {
    await pump(tester, withLongPress: false);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(seconds: 2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    expect(calls, ['press']);
  });

  testWidgets('las repeticiones horizontales se bloquean', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    expect(calls, ['right']);
  });

  testWidgets('las repeticiones verticales sí se entregan', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    expect(calls, ['down', 'down']);
  });

  testWidgets('perder el foco con OK apretado no deja tap pendiente',
      (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    node.unfocus();
    await tester.pump(TvTiming.longPress);
    expect(calls, isEmpty);
  });
}
