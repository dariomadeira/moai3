import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_text.dart';

import 'helpers/real_fonts.dart';

/// Los tests de desbordes cargan las fuentes reales: esto confirma que de
/// verdad cargaron (con la fuente de prueba de Flutter todo mide igual).
void main() {
  setUpAll(loadRealFonts);

  double width(String family, {FontWeight weight = FontWeight.w700}) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Buenas tardes',
        style: TextStyle(fontFamily: family, fontSize: 24, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  test('las fuentes reales están cargadas', () {
    // Cada familia mide distinto (con la de prueba medirían igual).
    expect(width('VarelaRound'), isNot(width('Unbounded')));
    expect(width('Unbounded'), greaterThan(width('Onest') * 1.2));
    // Y los pesos cambian el ancho (cada peso es su propio archivo).
    expect(
      width('MPLUSRounded1c', weight: FontWeight.w800),
      isNot(width('MPLUSRounded1c', weight: FontWeight.w300)),
    );
  });

  testWidgets('títulos y texto usan Varela Round', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    for (final style in [
      MoaiText.display(ctx),
      MoaiText.display(ctx, fontSize: 18),
      MoaiText.display(ctx, fontSize: 18, headline: true),
      MoaiText.body(ctx),
    ]) {
      expect(style.fontFamily, 'VarelaRound');
    }
  });
}
