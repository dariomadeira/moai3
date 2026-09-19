import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/controllers/player_overlay_controller.dart';

void main() {
  group('PlayerOverlayController', () {
    testWidgets('updatePlaceholderRect calcula rect desde RenderBox',
        (tester) async {
      final controller = PlayerOverlayController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: controller.placeholderKey,
              width: 320,
              height: 180,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      );
      await tester.pump();

      controller.updatePlaceholderRect();
      expect(controller.hasValidRect, isTrue);
      expect(controller.smallPlayerRect.width, 320);
      expect(controller.smallPlayerRect.height, 180);
    });

    testWidgets('sin context no crashea', (tester) async {
      final controller = PlayerOverlayController();
      expect(() => controller.updatePlaceholderRect(), returnsNormally);
      expect(controller.hasValidRect, isFalse);
    });

    testWidgets('tamaño cero no actualiza rect', (tester) async {
      final controller = PlayerOverlayController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: controller.placeholderKey,
              width: 0,
              height: 0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(() => controller.updatePlaceholderRect(), returnsNormally);
      expect(controller.hasValidRect, isFalse);
    });

    testWidgets('shouldRequestInitialFocus exige rect válido y no loading',
        (tester) async {
      final controller = PlayerOverlayController();
      expect(controller.shouldRequestInitialFocus(true), isFalse);
      expect(controller.shouldRequestInitialFocus(false), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              key: controller.placeholderKey,
              width: 200,
              height: 112,
            ),
          ),
        ),
      );
      await tester.pump();
      controller.updatePlaceholderRect();

      expect(controller.shouldRequestInitialFocus(true), isFalse);
      expect(controller.shouldRequestInitialFocus(false), isTrue);

      controller.markInitialFocusDone();
      expect(controller.shouldRequestInitialFocus(false), isFalse);
    });
  });
}

