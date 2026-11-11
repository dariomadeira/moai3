import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/moai_glass_pill.dart';

import 'helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('en una fila las pastillas caen en píxeles enteros', (
    tester,
  ) async {
    const labels = ['Aventura', 'Biografía', 'Drama', 'Ciencia ficción'];
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 8,
            children: [
              for (final l in labels)
                MoaiGlassPill(label: l, tone: MoaiGlassPillTone.dark),
            ],
          ),
        ),
      ),
    );
    for (final l in labels) {
      final r = tester.getRect(find.widgetWithText(MoaiGlassPill, l));
      expect(r.left, r.left.roundToDouble(), reason: l);
      expect(r.width, r.width.roundToDouble(), reason: l);
    }
  });
}
