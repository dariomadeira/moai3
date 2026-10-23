/// Formatos de fecha y hora de la app, en un solo lugar (SPEC-50 §3.4).
///
/// La app solo está en español (`kSupportedLocales`); si se suma otro idioma,
/// los nombres de meses y días pasan a las traducciones.
abstract final class MoaiFormats {
  static const _monthsShort = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  static const _weekdaysShort = [
    'LUN',
    'MAR',
    'MIÉ',
    'JUE',
    'VIE',
    'SÁB',
    'DOM',
  ];

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// `dd/MM/yyyy`.
  static String date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  /// `HH:mm`.
  static String time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  /// `Ene` … `Dic` para [month] 1–12.
  static String monthShort(int month) => _monthsShort[(month - 1).clamp(0, 11)];

  /// `LUN` … `DOM` para [weekday] 1–7 (`DateTime.monday` = 1).
  static String weekdayShort(int weekday) =>
      _weekdaysShort[(weekday - 1).clamp(0, 6)];

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
