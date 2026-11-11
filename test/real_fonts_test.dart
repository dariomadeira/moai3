import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_text.dart';

import 'helpers/real_fonts.dart';

/// Los tests de desbordes cargan la fuente real: esto confirma que de verdad
/// cargó (con la fuente de prueba de Flutter todo mide igual).
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

  test('la fuente real está cargada', () {
    // Con la de prueba de Flutter (una familia sin cargar cae en ella) mediría
    // igual.
    expect(width('VarelaRound'), isNot(width('SinCargar')));
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
