import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/alphabet_jump_panel.dart';

void main() {
  /// Color de arriba del fondo de la letra (null = sin fondo).
  Color? focusFill(WidgetTester tester, String letter) {
    final box = find.descendant(
      of: find.byKey(ValueKey('alpha-$letter')),
      matching: find.byType(DecoratedBox),
    );
    // En reposo la letra va suelta: sin caja.
    if (box.evaluate().isEmpty) return null;
    final d =
        tester.widget<DecoratedBox>(box.first).decoration as BoxDecoration;
    final color = d.gradient?.colors.last ?? d.color;
    return color == null || color.a == 0 ? null : color;
  }

  testWidgets('la letra con foco se pinta del acento al instante, también al '
      'correrse la ventana', (tester) async {
    final letters = List.generate(20, (i) => String.fromCharCode(65 + i));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 38,
            height: 400,
            child: AlphabetJumpPanel(letters: letters, onLetterTap: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final accent = Theme.of(
      tester.element(find.byType(AlphabetJumpPanel)),
    ).colorScheme.primary;

    for (var i = 0; i < letters.length + 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      // Sin fundido: dos cuadros alcanzan (el foco se pide al siguiente).
      await tester.pump();
      await tester.pump();

      // La letra con foco (la que está dentro del nodo primario).
      final primary = FocusManager.instance.primaryFocus!.context!;
      final focused = letters.firstWhere(
        (l) => find
            .ancestor(
              of: find.byElementPredicate((e) => e == primary),
              matching: find.byKey(ValueKey('alpha-$l')),
            )
            .evaluate()
            .isNotEmpty,
      );
      final visible = [
        for (final l in letters)
          if (find.byKey(ValueKey('alpha-$l')).evaluate().isNotEmpty) l,
      ];
      for (final l in visible) {
        expect(
          focusFill(tester, l),
          l == focused ? accent : isNull,
          reason: 'paso $i, letra $l (foco en $focused)',
        );
      }
    }
  });
}
