import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/widgets/discounts_settings_panel.dart';
import 'package:moai3/features/discounts/widgets/discounts_week_panel.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Sección Descuentos del rail (SPEC-43): acordeón de 2 paneles, la semana
/// y Configurar. Más adelante, las listas de compras.
class HomeDiscountsArea extends StatefulWidget {
  const HomeDiscountsArea({
    super.key,
    required this.onExitLeft,
    this.initialPanelIndex = 0,
    this.initialDayIndex = 0,
    this.onPanelIndexChanged,
  });

  final VoidCallback onExitLeft;
  final int initialPanelIndex;

  /// Día elegido al entrar desde la tarjeta del Inicio (0 = hoy).
  final int initialDayIndex;
  final ValueChanged<int>? onPanelIndexChanged;

  static const icons = [MoaiIcons.discounts, MoaiIcons.discountFilter];

  @override
  State<HomeDiscountsArea> createState() => HomeDiscountsAreaState();
}

class HomeDiscountsAreaState extends HomeAreaState<HomeDiscountsArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _weekFocus = FocusNode(debugLabel: 'discounts_week');
  final _settingsFocus = FocusNode(debugLabel: 'discounts_settings');
  late int _panel = widget.initialPanelIndex;

  /// Conserva el día e ítem seleccionados de la semana y de configuración al alternar paneles.
  late int _discountsDay = widget.initialDayIndex;
  int _discountsDayItem = 0;
  int _discountsSettingsItem = 0;

  @override
  void didUpdateWidget(covariant HomeDiscountsArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPanelIndex != widget.initialPanelIndex) {
      _panel = widget.initialPanelIndex;
    }
    if (oldWidget.initialDayIndex != widget.initialDayIndex) {
      _discountsDay = widget.initialDayIndex;
    }
  }

  @override
  void dispose() {
    _weekFocus.dispose();
    _settingsFocus.dispose();
    super.dispose();
  }

  @override
  void requestEntryFocus() =>
      _focus.node(_panel == 0 ? _weekFocus : _settingsFocus, immediate: true);

  void _openPanel(int index) {
    setState(() => _panel = index);
    widget.onPanelIndexChanged?.call(index);
    requestEntryFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    // Ancho final fijo: las tarjetas de comercios no se deforman mientras el
    // acordeón abre o cambia de panel.
    return TvAccordionRowPreview(
      panelCount: 2,
      activeIndex: _panel,
      colors: [
        scheme.surface.withValues(alpha: 0.8),
        scheme.surface.withValues(alpha: 0.8),
      ],
      titles: [
        LocaleKeys.discounts_panel_week.tr(),
        LocaleKeys.discounts_settings_title.tr(),
      ],
      icons: HomeDiscountsArea.icons,
      onPanelTap: _openPanel,
      fixedContentWidth: true,
      buildExpandedContent: (index, title) {
        return index == 0
            ? DiscountsWeekPanel(
                focusNode: _weekFocus,
                initialDayIndex: _discountsDay,
                initialItemIndex: _discountsDayItem,
                onDayChanged: (d) => _discountsDay = d,
                onItemChanged: (item) => _discountsDayItem = item,
                onKeyLeft: widget.onExitLeft,
                onKeyRight: () => _openPanel(1),
              )
            : DiscountsSettingsPanel(
                focusNode: _settingsFocus,
                initialIndex: _discountsSettingsItem,
                onSelectedIndexChanged: (idx) => _discountsSettingsItem = idx,
                onKeyLeft: () => _openPanel(0),
              );
      },
    );
  }
}
