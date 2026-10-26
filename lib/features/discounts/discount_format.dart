import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/utils/moai_formats.dart';

/// Textos de los descuentos, en un solo lugar.
abstract final class DiscountFormat {
  /// `$12.000` (pesos, sin decimales, con punto de miles).
  static String money(double amount) {
    final digits = amount.round().toString();
    final sb = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) sb.write('.');
      sb.write(digits[i]);
    }
    return '\$$sb';
  }

  /// `20%` o, sin porcentaje, el texto de MODO.
  static String headline(Discount d) {
    final p = d.percent;
    if (p == null) return d.benefit;
    return '${p == p.roundToDouble() ? p.round() : p}%';
  }

  /// `Tope $12.000 por mes` / `Sin tope`.
  static String cap(Discount d) {
    final cap = d.cap;
    if (cap == null) return LocaleKeys.discounts_no_cap.tr();
    final period = switch (d.capPeriod) {
      DiscountCapPeriod.day => LocaleKeys.discounts_cap_per_day.tr(),
      DiscountCapPeriod.week => LocaleKeys.discounts_cap_per_week.tr(),
      DiscountCapPeriod.month => LocaleKeys.discounts_cap_per_month.tr(),
      DiscountCapPeriod.none => '',
    };
    final base = LocaleKeys.discounts_cap.tr(namedArgs: {'amount': money(cap)});
    return period.isEmpty ? base : '$base $period';
  }

  /// Con qué tarjetas: todas las grandes juntas se resumen.
  static String cards(Discount d) {
    if (d.cardBrands.isEmpty) return '';
    if (d.cardBrands.length >= 5) return LocaleKeys.discounts_any_card.tr();
    return d.cardBrands.join(', ');
  }

  /// `Hoy`, `Mañana` o `MIÉ 28 Oct`.
  static String day(DateTime day, DateTime today) {
    final d = DateTime(day.year, day.month, day.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return LocaleKeys.discounts_today.tr();
    if (diff == 1) return LocaleKeys.discounts_tomorrow.tr();
    return '${MoaiFormats.weekdayShort(d.weekday)} ${d.day}';
  }
}
