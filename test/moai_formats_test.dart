import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'helpers/spanish_translations.dart';

void main() {
  group('MoaiFormats', () {
    test('fecha y hora con ceros', () {
      final d = DateTime(2026, 3, 7, 9, 5);
      expect(MoaiFormats.date(d), '07/03/2026');
      expect(MoaiFormats.time(d), '09:05');
    });

    test('nombres cortos de mes y día', () {
      useSpanishTranslations();
      expect(MoaiFormats.monthShort(1), 'Ene');
      expect(MoaiFormats.monthShort(12), 'Dic');
      expect(MoaiFormats.weekdayShort(DateTime.monday), 'LUN');
      expect(MoaiFormats.weekdayShort(DateTime.sunday), 'DOM');
    });

    test('rango de semana en un mes, entre meses y entre años', () {
      useSpanishTranslations();
      expect(
        MoaiFormats.weekRange(DateTime(2026, 10, 19), DateTime(2026, 10, 25)),
        '19 - 25 Oct 2026',
      );
      expect(
        MoaiFormats.weekRange(DateTime(2026, 9, 28), DateTime(2026, 10, 4)),
        '28 Sep - 4 Oct 2026',
      );
      expect(
        MoaiFormats.weekRange(DateTime(2025, 12, 29), DateTime(2026, 1, 4)),
        '29 Dic 2025 - 4 Ene 2026',
      );
    });
  });
}
