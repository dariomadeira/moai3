import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';

import 'helpers/spanish_translations.dart';

void main() {
  testWidgets('muestra la hora y la fecha corta', (tester) async {
    useSpanishTranslations();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Domingo 25 de octubre de 2026, 9:05.
          body: HomeClock(now: () => DateTime(2026, 10, 25, 9, 5)),
        ),
      ),
    );
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('DOM · 25 Oct'), findsOneWidget);
  });

  testWidgets('se actualiza al cambiar el minuto', (tester) async {
    useSpanishTranslations();
    var now = DateTime(2026, 10, 25, 9, 5, 50);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeClock(now: () => now)),
      ),
    );
    expect(find.text('09:05'), findsOneWidget);
    now = DateTime(2026, 10, 25, 9, 6);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('09:06'), findsOneWidget);
  });
}
