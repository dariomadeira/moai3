import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/utils/moai_formats.dart';

/// Textos de los descuentos, en un solo lugar.
abstract final class DiscountFormat {
  /// `$12.000` (pesos, sin decimales, con punto de miles).
  static String money(double amount) =>
      '\$${MoaiFormats.thousands(amount.round())}';

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

  /// Nombre del rubro ("Supermercados", "Farmacias"…).
  static String rubro(DiscountRubro r) => switch (r) {
    DiscountRubro.supermercados => LocaleKeys.discounts_rubro_super.tr(),
    DiscountRubro.mayoristas => LocaleKeys.discounts_rubro_mayoristas.tr(),
    DiscountRubro.farmacias => LocaleKeys.discounts_rubro_farmacias.tr(),
    DiscountRubro.combustible => LocaleKeys.discounts_rubro_combustible.tr(),
  };

  /// Qué entra en el rubro ("Coto, Carrefour, Día…").
  static String rubroDescription(DiscountRubro r) => switch (r) {
    DiscountRubro.supermercados => LocaleKeys.discounts_rubro_super_desc.tr(),
    DiscountRubro.mayoristas => LocaleKeys.discounts_rubro_mayoristas_desc.tr(),
    DiscountRubro.farmacias => LocaleKeys.discounts_rubro_farmacias_desc.tr(),
    DiscountRubro.combustible =>
      LocaleKeys.discounts_rubro_combustible_desc.tr(),
  };

  /// Ícono del rubro.
  static IconData rubroIcon(DiscountRubro r) => switch (r) {
    DiscountRubro.supermercados => MoaiIcons.discountRubroSuper,
    DiscountRubro.mayoristas => MoaiIcons.discountRubroMayoristas,
    DiscountRubro.farmacias => MoaiIcons.discountRubroFarmacias,
    DiscountRubro.combustible => MoaiIcons.discountRubroCombustible,
  };

  /// Qué días vale: `Todos los días` o `LUN, MIÉ`.
  static String weekdays(Discount d) {
    if (d.weekdays.isEmpty || d.weekdays.length == 7) {
      return LocaleKeys.discounts_every_day.tr();
    }
    return (d.weekdays.toList()..sort())
        .map(MoaiFormats.weekdayShort)
        .join(', ');
  }

  /// Vigencia: `Hasta 31/10/2026`, `Desde 01/11/2026` o vacío.
  static String validity(Discount d) {
    if (d.stop != null) {
      return LocaleKeys.discounts_until.tr(
        namedArgs: {'date': MoaiFormats.date(d.stop!)},
      );
    }
    if (d.start != null) {
      return LocaleKeys.discounts_from.tr(
        namedArgs: {'date': MoaiFormats.date(d.start!)},
      );
    }
    return '';
  }

  /// Dónde se paga: en el local, en línea o ambos.
  static String where(Discount d) => [
    if (d.instore) LocaleKeys.discounts_instore.tr(),
    if (d.online) LocaleKeys.discounts_online.tr(),
  ].join(' · ');

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
