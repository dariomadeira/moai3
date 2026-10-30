import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/discounts/widgets/discount_dialogs.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/week/tv_week_grid.dart';

enum _Section { header, grid }

enum _HeaderAction { mine, rubro, refresh }

/// Panel 0 de Descuentos: los próximos 7 días (hoy primero) en columnas,
/// cada una con sus descuentos del mejor al peor, como la semana de la
/// Agenda. Arriba, los filtros: Mis comercios / Todos y el rubro.
///
/// ←/→ cambian de día (y salen al rail o a Configurar en las puntas), ↑/↓
/// recorren el día y suben a los filtros, OK abre el detalle.
class DiscountsWeekPanel extends StatefulWidget {
  const DiscountsWeekPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialDayIndex = 0,
    this.initialItemIndex = 0,
    this.onDayChanged,
    this.onItemChanged,
    this.now,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;

  /// → desde el último día o filtro: al panel Configurar.
  final VoidCallback onKeyRight;

  /// Día elegido al entrar (0 = hoy), p. ej. desde la tarjeta del Inicio.
  final int initialDayIndex;

  /// Ítem elegido al entrar.
  final int initialItemIndex;
  final ValueChanged<int>? onDayChanged;
  final ValueChanged<int>? onItemChanged;

  /// Hoy (tests); sin él, la fecha del aparato.
  final DateTime Function()? now;

  static const int days = 7;

  @override
  State<DiscountsWeekPanel> createState() => _DiscountsWeekPanelState();
}

class _DiscountsWeekPanelState extends State<DiscountsWeekPanel> {
  static const _windowSize = 4;

  final _service = DiscountsService.instance;
  _Section _section = _Section.grid;
  int _headerIndex = 0;
  late int _day = widget.initialDayIndex.clamp(0, DiscountsWeekPanel.days - 1);

  /// Rubro elegido en el filtro (null: todos los que le interesan).
  DiscountRubro? _rubro;
  final _itemIndex = List<int>.filled(DiscountsWeekPanel.days, 0);
  final _windowStart = List<int>.filled(DiscountsWeekPanel.days, 0);

  @override
  void initState() {
    super.initState();
    _service.ensureLoaded();
    _itemIndex[_day] = widget.initialItemIndex;
    if (widget.initialItemIndex >= _windowSize) {
      _windowStart[_day] = widget.initialItemIndex - _windowSize + 1;
    }
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant DiscountsWeekPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDayIndex != widget.initialDayIndex) {
      _day = widget.initialDayIndex.clamp(0, DiscountsWeekPanel.days - 1);
      _section = _Section.grid;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _today => (widget.now ?? DateTime.now)();

  List<DayDiscounts> get _week => _service.week(_today, rubro: _rubro);

  /// Rubros para el filtro: todos (null) y los que le interesan.
  List<DiscountRubro?> get _rubroOptions => [
    null,
    for (final r in DiscountRubro.values)
      if (_service.rubros.contains(r)) r,
  ];

  void _runHeader(_HeaderAction action) {
    switch (action) {
      case _HeaderAction.mine:
        _service.setOnlyMine(!_service.onlyMine);
      case _HeaderAction.rubro:
        final options = _rubroOptions;
        final next = (options.indexOf(_rubro) + 1) % options.length;
        setState(() => _rubro = options[next]);
      case _HeaderAction.refresh:
        _service.refresh(force: true);
    }
    _resetWindows();
  }

  void _resetWindows() {
    _itemIndex.fillRange(0, DiscountsWeekPanel.days, 0);
    _windowStart.fillRange(0, DiscountsWeekPanel.days, 0);
  }

  void _moveItem(int delta, int count) {
    final next = _itemIndex[_day] + delta;
    if (next < 0 || next >= count) return;
    setState(() {
      _itemIndex[_day] = next;
      widget.onItemChanged?.call(next);
      if (next < _windowStart[_day]) _windowStart[_day] = next;
      if (next >= _windowStart[_day] + _windowSize) {
        _windowStart[_day] = next - _windowSize + 1;
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final week = _week;
    final dayList = week[_day].discounts;

    if (_section == _Section.header) {
      const actions = _HeaderAction.values;
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_headerIndex > 0) {
          setState(() => _headerIndex--);
        } else {
          widget.onKeyLeft();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        if (_headerIndex < actions.length - 1) {
          setState(() => _headerIndex++);
        } else {
          widget.onKeyRight();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _section = _Section.grid);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && TvKeyHandler.isActionKey(key)) {
        _runHeader(actions[_headerIndex]);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_day > 0) {
        setState(() => _day--);
        widget.onDayChanged?.call(_day);
        widget.onItemChanged?.call(_itemIndex[_day]);
      } else {
        widget.onKeyLeft();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_day < DiscountsWeekPanel.days - 1) {
        setState(() => _day++);
        widget.onDayChanged?.call(_day);
        widget.onItemChanged?.call(_itemIndex[_day]);
      } else {
        widget.onKeyRight();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_itemIndex[_day] > 0 && dayList.isNotEmpty) {
        _moveItem(-1, dayList.length);
      } else {
        setState(() => _section = _Section.header);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveItem(1, dayList.length);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && TvKeyHandler.isActionKey(key)) {
      if (dayList.isNotEmpty) {
        final i = _itemIndex[_day].clamp(0, dayList.length - 1);
        TvDiscountDetailDialog.show(context, dayList[i]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final scheme = context.scheme;
        final focused = widget.focusNode.hasFocus;
        if (_rubro != null && !_service.rubros.contains(_rubro)) _rubro = null;
        final week = _week;
        final emptyText = !_service.hasSelectedBanks
            ? LocaleKeys.discounts_choose_banks_short.tr()
            : _service.isLoading
            ? LocaleKeys.discounts_loading.tr()
            : LocaleKeys.discounts_none_short.tr();

        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: _onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado como el de la Agenda: la semana a la izquierda y
              // los botones a la derecha.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isUltraCompact = constraints.maxWidth < 360;
                    final isCompact = constraints.maxWidth < 480;

                    return Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                MoaiIcons.discounts,
                                size: MoaiIconSizes.md,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  MoaiFormats.weekRange(
                                    week.first.day,
                                    week.last.day,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MoaiText.display(
                                    context,
                                    fontSize: 15,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final (i, action) in _HeaderAction.values.indexed)
                          Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                            child: TvWeekHeaderButton(
                              icon: switch (action) {
                                _HeaderAction.mine => MoaiIcons.discountMerchants,
                                _HeaderAction.rubro =>
                                  _rubro == null
                                      ? MoaiIcons.discountFilter
                                      : DiscountFormat.rubroIcon(_rubro!),
                                _HeaderAction.refresh => MoaiIcons.refresh,
                              },
                              label: switch (action) {
                                _HeaderAction.mine => isUltraCompact
                                    ? null
                                    : _service.onlyMine
                                    ? LocaleKeys.discounts_filter_mine.tr()
                                    : (isCompact ? 'Todos' : LocaleKeys.discounts_filter_all.tr()),
                                _HeaderAction.rubro => isUltraCompact
                                    ? null
                                    : _rubro == null
                                    ? (isCompact ? 'Rubros' : LocaleKeys.discounts_filter_all_rubros.tr())
                                    : DiscountFormat.rubro(_rubro!),
                                _HeaderAction.refresh => null,
                              },
                              tooltip: switch (action) {
                                _HeaderAction.mine => _service.onlyMine
                                    ? LocaleKeys.discounts_filter_mine.tr()
                                    : LocaleKeys.discounts_filter_all.tr(),
                                _HeaderAction.rubro => _rubro == null
                                    ? LocaleKeys.discounts_filter_all_rubros.tr()
                                    : DiscountFormat.rubro(_rubro!),
                                _HeaderAction.refresh => LocaleKeys.calendar_refresh.tr(),
                              },
                              isLoading:
                                  action == _HeaderAction.refresh &&
                                  _service.isLoading,
                              isFocused:
                                  focused &&
                                  _section == _Section.header &&
                                  _headerIndex == i,
                              onTap: () {
                                setState(() {
                                  _section = _Section.header;
                                  _headerIndex = i;
                                });
                                _runHeader(action);
                                widget.focusNode.requestFocus();
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 10, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < week.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: TvWeekDayColumn(
                              weekdayLabel: MoaiFormats.weekdayShort(
                                week[i].day.weekday,
                              ),
                              dayNumber: week[i].day.day,
                              isToday: i == 0,
                              itemCount: week[i].discounts.length,
                              isColumnFocused:
                                  focused &&
                                  _section == _Section.grid &&
                                  _day == i,
                              selectedIndex: _itemIndex[i],
                              windowStart: _windowStart[i],
                              windowSize: _windowSize,
                              emptyIcon: MoaiIcons.discounts,
                              emptyText: emptyText,
                              onSelectColumn: () {
                                setState(() {
                                  _section = _Section.grid;
                                  _day = i;
                                });
                                widget.onDayChanged?.call(i);
                                widget.onItemChanged?.call(_itemIndex[i]);
                                widget.focusNode.requestFocus();
                              },
                              itemBuilder: (context, index, isFocused, height) {
                                final d = week[i].discounts[index];
                                return _DiscountGridCard(
                                  discount: d,
                                  isFocused: isFocused,
                                  height: height,
                                  province: _service.province,
                                  onTap: () {
                                    setState(() {
                                      _section = _Section.grid;
                                      _day = i;
                                      _itemIndex[i] = index;
                                    });
                                    widget.onDayChanged?.call(i);
                                    widget.onItemChanged?.call(_itemIndex[i]);
                                    widget.focusNode.requestFocus();
                                    TvDiscountDetailDialog.show(context, d);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de una promo en la semana, como la de un evento de la Agenda:
/// arriba el ícono del rubro, el porcentaje y, si nombra mi provincia, un
/// chip; abajo el comercio.
class _DiscountGridCard extends StatelessWidget {
  const _DiscountGridCard({
    required this.discount,
    required this.isFocused,
    required this.height,
    required this.province,
    required this.onTap,
  });

  final Discount discount;
  final bool isFocused;
  final double height;
  final String? province;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final d = discount;
    final mine = d.mentions(province);
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: onTap,
        child: MoaiGlass(
          borderRadius: 12,
          elevated: false,
          solid: true,
          focused: isFocused,
          tint: mine ? scheme.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FittedBox: no desborda en ningún ancho ni transición.
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        DiscountFormat.rubroIcon(d.rubro),
                        size: MoaiIconSizes.xs,
                        color: scheme.primary.withValues(
                          alpha: isFocused ? 1 : 0.75,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DiscountFormat.headline(d),
                        style: MoaiText.display(
                          context,
                          fontSize: 10.5,
                          color: scheme.primary,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 5),
                        TvWeekStatusChip(
                          label: province!.toUpperCase(),
                          style: TvWeekChipStyle.highlighted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  d.merchant.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
