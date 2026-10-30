import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Formatos de fecha y hora de la app, en un solo lugar (SPEC-50 §3.4).
///
/// Los nombres cortos de meses y días salen de `es.json`.
abstract final class MoaiFormats {
  static const _monthsShort = [
    LocaleKeys.common_month_short_01,
    LocaleKeys.common_month_short_02,
    LocaleKeys.common_month_short_03,
    LocaleKeys.common_month_short_04,
    LocaleKeys.common_month_short_05,
    LocaleKeys.common_month_short_06,
    LocaleKeys.common_month_short_07,
    LocaleKeys.common_month_short_08,
    LocaleKeys.common_month_short_09,
    LocaleKeys.common_month_short_10,
    LocaleKeys.common_month_short_11,
    LocaleKeys.common_month_short_12,
  ];
  static const _weekdaysShort = [
    LocaleKeys.common_weekday_short_1,
    LocaleKeys.common_weekday_short_2,
    LocaleKeys.common_weekday_short_3,
    LocaleKeys.common_weekday_short_4,
    LocaleKeys.common_weekday_short_5,
    LocaleKeys.common_weekday_short_6,
    LocaleKeys.common_weekday_short_7,
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Entero con punto de miles: `31.419`.
  static String thousands(int n) {
    final digits = n.abs().toString();
    final sb = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) sb.write('.');
      sb.write(digits[i]);
    }
    return sb.toString();
  }

  /// `dd/MM/yyyy`.
  static String date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// `HH:mm`.
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// `Ene` … `Dic` para [month] 1–12.
  static String monthShort(int month) =>
      _monthsShort[(month - 1).clamp(0, 11)].tr();

  /// `LUN` … `DOM` para [weekday] 1–7 (`DateTime.monday` = 1).
  static String weekdayShort(int weekday) =>
      _weekdaysShort[(weekday - 1).clamp(0, 6)].tr();

  /// Rango de una semana: `19 - 25 Oct 2026`, `27 Oct - 2 Nov 2026` o
  /// `29 Dic 2025 - 4 Ene 2026`.
  static String weekRange(DateTime monday, DateTime sunday) {
    final end = '${sunday.day} ${monthShort(sunday.month)} ${sunday.year}';
    if (monday.month == sunday.month && monday.year == sunday.year) {
      return '${monday.day} - $end';
    }
    if (monday.year == sunday.year) {
      return '${monday.day} ${monthShort(monday.month)} - $end';
    }
    return '${monday.day} ${monthShort(monday.month)} ${monday.year} - $end';
  }
}
