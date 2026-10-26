import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/discounts/widgets/discount_dialogs.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

/// Tarjeta "Descuentos" del Inicio con su manejo de teclas: resumen de la
/// semana con los bancos, comercios y rubros del usuario. ←/→ recorren el
/// botón "Configurar" y los 7 días; OK abre la sección Descuentos en ese
/// día o en Configurar.
class HomeDiscountsItem extends StatefulWidget {
  const HomeDiscountsItem({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    this.onOpen,
    this.now,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  /// Abre la sección Descuentos en el día [dayIndex] o en Configurar.
  final void Function({int dayIndex, bool settings})? onOpen;

  /// Hoy (tests); sin él, la fecha del aparato.
  final DateTime Function()? now;

  @override
  State<HomeDiscountsItem> createState() => _HomeDiscountsItemState();
}

class _HomeDiscountsItemState extends State<HomeDiscountsItem> {
  static const _banksButton = HomeDiscountsCard.banksIndex;
  static const _days = 7;

  late bool _focused = widget.focusNode.hasFocus;

  /// Elegido: el botón "Mis bancos" o un día (0 = hoy).
  int _index = 0;

  final _service = DiscountsService.instance;

  @override
  void initState() {
    super.initState();
    _service.ensureLoaded();
  }

  DateTime get _today => (widget.now ?? DateTime.now)();

  void _press() {
    final open = widget.onOpen;
    if (_index == _banksButton || !_service.hasSelectedBanks) {
      // Sin la sección (tests), los bancos directo.
      if (open == null) {
        TvDiscountBanksDialog.show(context);
      } else {
        open(settings: true);
      }
      return;
    }
    open?.call(dayIndex: _index);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final week = _service.week(_today);
        return TvPressDetector(
          focusNode: widget.focusNode,
          onFocusChange: (f) => setState(() => _focused = f),
          onPress: _press,
          onLeft: () {
            if (_index > _banksButton) {
              setState(() => _index--);
            } else {
              widget.onKeyLeft();
            }
            return true;
          },
          onRight: () {
            // Sin bancos elegidos sólo está el botón.
            if (_service.hasSelectedBanks && _index < _days - 1) {
              setState(() => _index++);
            }
            return true;
          },
          onUp: widget.onKeyUp,
          onDown: widget.onKeyDown,
          child: GestureDetector(
            onTap: _press,
            child: HomeDiscountsCard(
              week: week,
              today: _today,
              hasBanks: _service.hasSelectedBanks,
              isLoading: _service.isLoading,
              selectedIndex: _service.hasSelectedBanks ? _index : _banksButton,
              isFocused: _focused,
            ),
          ),
        );
      },
    );
  }
}

/// Lo que se ve de la tarjeta: resumen con el botón y la semana.
class HomeDiscountsCard extends StatelessWidget {
  const HomeDiscountsCard({
    super.key,
    required this.week,
    required this.today,
    required this.hasBanks,
    required this.selectedIndex,
    this.isLoading = false,
    this.isFocused = false,
  });

  final List<DayDiscounts> week;
  final DateTime today;
  final bool hasBanks;
  final bool isLoading;

  /// Día elegido (0 = hoy) o [banksIndex].
  final int selectedIndex;
  final bool isFocused;

  /// [selectedIndex] del botón "Mis bancos".
  static const int banksIndex = -1;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final onDay = isFocused && hasBanks && selectedIndex != banksIndex;

    return HomeCard(
      glow: HomeCardColors.discounts,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 214,
            child: _Summary(
              line: !hasBanks
                  ? LocaleKeys.discounts_choose_banks.tr()
                  : onDay
                  ? LocaleKeys.discounts_hint.tr()
                  : LocaleKeys.discounts_subtitle.tr(),
              highlightLine: onDay || !hasBanks,
              buttonFocused: isFocused && selectedIndex == banksIndex,
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 12),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: !hasBanks
                ? _Message(LocaleKeys.discounts_empty_banks.tr())
                : week.every((d) => d.discounts.isEmpty)
                ? _Message(
                    isLoading
                        ? LocaleKeys.discounts_loading.tr()
                        : LocaleKeys.discounts_none_week.tr(),
                  )
                : Row(
                    children: [
                      for (var i = 0; i < week.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _DayColumn(
                            day: week[i],
                            label: DiscountFormat.day(week[i].day, today),
                            isToday: i == 0,
                            focused: isFocused && selectedIndex == i,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.line,
    required this.highlightLine,
    required this.buttonFocused,
  });

  final String line;
  final bool highlightLine;
  final bool buttonFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              MoaiIcons.discounts,
              size: MoaiIconSizes.lg,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                LocaleKeys.discounts_title.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: highlightLine ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: moaiGlassButtonDecoration(
            scheme,
            focused: buttonFocused,
            radius: 16,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MoaiIcons.discountBanks,
                size: MoaiIconSizes.sm,
                color: buttonFocused ? scheme.onPrimary : scheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  LocaleKeys.discounts_configure.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: buttonFocused ? scheme.onPrimary : scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un día: el mejor descuento y cuántos más hay.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.label,
    required this.isToday,
    required this.focused,
  });

  final DayDiscounts day;
  final String label;
  final bool isToday;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final best = day.best;
    final more = day.discounts.length - 1;

    return MoaiGlass(
      borderRadius: 10,
      elevated: false,
      solid: true,
      focused: focused,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: isToday ? scheme.primary : scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            best == null ? '—' : DiscountFormat.headline(best),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.display(
              context,
              color: best == null ? scheme.onSurfaceVariant : scheme.onSurface,
              fontSize: 18,
              height: 1.15,
            ),
          ),
          Text(
            best?.merchant ?? LocaleKeys.discounts_none_short.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: scheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (more > 0)
            Text(
              LocaleKeys.discounts_more.tr(namedArgs: {'n': '$more'}),
              maxLines: 1,
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: MoaiText.body(
          context,
          color: context.scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
