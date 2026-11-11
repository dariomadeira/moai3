import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool selected}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: MoaiPillButton(
            kind: MoaiPillButtonKind.glass,
            icon: Icons.play_arrow,
            label: 'Reproducir',
            selected: selected,
          ),
        ),
      ),
    );
  }

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(MoaiPillButton),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  testWidgets('al tomar el foco pasa de vidrio a azul sin parpadear', (
    tester,
  ) async {
    await pump(tester, selected: false);
    await pump(tester, selected: true);
    final primary = Theme.of(
      tester.element(find.byType(MoaiPillButton)),
    ).colorScheme.primary;

    // A mitad de la animación: sólo degradado (un color de fondo atenuaba el
    // degradado y se veía azul tenue → blanco → azul).
    await tester.pump(const Duration(milliseconds: 70));
    final mid = decoration(tester);
    expect(mid.color, isNull);
    final bottom = mid.gradient!.colors.last;
    expect(bottom, isNot(primary));
    expect(bottom.a, greaterThan(0.3), reason: 'no se apaga en el medio');

    await tester.pumpAndSettle();
    expect(decoration(tester).gradient!.colors.last, primary);
  });
}
