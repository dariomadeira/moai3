import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/collapsed_panel_tab_preview.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';

void main() {
  Widget accordion(int active) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 1000,
          height: 400,
          child: TvAccordionRowPreview(
            panelCount: 7,
            activeIndex: active,
            colors: List.filled(7, Colors.white),
            titles: [for (var i = 0; i < 7; i++) 'P$i'],
            icons: List.filled(7, Icons.circle),
            onPanelTap: (_) {},
            buildExpandedContent: (index, title) => Text('contenido $title'),
          ),
        ),
      ),
    ),
  );

  testWidgets(
    'pasar rápido de panel no corre la fila: el último queda quieto',
    (tester) async {
      await tester.pumpWidget(accordion(0));
      final lastTab = find.byType(CollapsedPanelTabPreview).last;
      final resting = tester.getTopLeft(lastTab).dx;

      // Cada cambio corta la animación anterior a mitad.
      for (final (active, ms) in [(1, 90), (2, 40), (3, 120), (2, 60)]) {
        await tester.pumpWidget(accordion(active));
        await tester.pump(Duration(milliseconds: ms));
        expect(tester.getTopLeft(lastTab).dx, moreOrLessEquals(resting));
      }

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(lastTab).dx, moreOrLessEquals(resting));
      expect(tester.takeException(), isNull);
    },
  );
}
