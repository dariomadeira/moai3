import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_theme.dart';
import 'package:moai3/widgets/buttons/tv_icon_action_button.dart';

void main() {
  /// El borrar de Extensiones, enfocado, en cristal.
  Future<void> pumpDelete(WidgetTester tester, {required bool dark}) async {
    final seed = MoaiAccentColors.seedAt(0);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? MoaiTheme.dark(seed) : MoaiTheme.light(seed),
        home: Scaffold(
          body: Center(
            child: TvIconActionButton(
              focusNode: focus,
              tooltip: 'Quitar',
              icon: MoaiIcons.delete,
              destructive: true,
              onPressed: () {},
              parentFocused: true,
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('borrar con foco: rojo con el ícono blanco '
        '(${dark ? 'oscuro' : 'claro'})', (tester) async {
      await pumpDelete(tester, dark: dark);
      expect(
        tester.widget<Icon>(find.byIcon(MoaiIcons.delete)).color,
        Colors.white,
      );
      final box = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.byIcon(MoaiIcons.delete),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final gradient =
          (box.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors.last, const Color(0xFFBA1A1A));
    });
  }
}
