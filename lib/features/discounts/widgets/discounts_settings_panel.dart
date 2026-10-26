import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/discounts/widgets/discount_dialogs.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/dialogs/tv_weather_location_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';

/// Panel 1 de Descuentos: bancos y billeteras, mis comercios, mi localidad
/// (la del clima) y los rubros que interesan.
class DiscountsSettingsPanel extends StatefulWidget {
  const DiscountsSettingsPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
  });

  final FocusNode focusNode;

  /// ← vuelve a la semana.
  final VoidCallback onKeyLeft;

  @override
  State<DiscountsSettingsPanel> createState() => _DiscountsSettingsPanelState();
}

/// Una fila: una acción o un rubro para prender y apagar.
sealed class _Item {
  const _Item();
}

enum _Action { banks, merchants, location }

class _ActionItem extends _Item {
  const _ActionItem(this.action);
  final _Action action;
}

class _RubroItem extends _Item {
  const _RubroItem(this.rubro);
  final DiscountRubro rubro;
}

class _DiscountsSettingsPanelState extends State<DiscountsSettingsPanel> {
  static const _windowSize = 6;
  static const _itemExtent = 70.0;

  static final _items = <_Item>[
    for (final a in _Action.values) _ActionItem(a),
    for (final r in DiscountRubro.values) _RubroItem(r),
  ];

  final _listKey = GlobalKey<TvWindowedListState<_Item>>();
  final _service = DiscountsService.instance;
  int _selected = 0;

  String _count(int n) => switch (n) {
    0 => LocaleKeys.discounts_none_selected.tr(),
    1 => LocaleKeys.discounts_one_selected.tr(),
    _ => LocaleKeys.discounts_n_selected.tr(namedArgs: {'n': '$n'}),
  };

  @override
  Widget build(BuildContext context) {
    final weather = context.watch<WeatherProvider?>();
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        if (f) _listKey.currentState?.ensureVisible(_selected);
      },
      child: ListenableBuilder(
        listenable: _service,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvPanelHeader(
                title: LocaleKeys.discounts_settings_title.tr(),
                subtitle: LocaleKeys.discounts_settings_subtitle.tr(),
              ),
              // Igual que Agenda › Suscripciones: la ventana de 6 filas
              // pegada abajo, con aire bajo el título.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: (_windowSize * _itemExtent).clamp(
                        0.0,
                        constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TvWindowedList<_Item>(
                          key: _listKey,
                          focusOnMount: false,
                          items: _items,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selected,
                          onFocusedGlobalIndex: (i) => _selected = i,
                          itemBuilder:
                              (
                                context,
                                item,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: switch (item) {
                                  _ActionItem(:final action) =>
                                    TvSettingsActionRow(
                                      focusNode: focusNode,
                                      icon: switch (action) {
                                        _Action.banks =>
                                          MoaiIcons.discountBanks,
                                        _Action.merchants =>
                                          MoaiIcons.discountMerchants,
                                        _Action.location =>
                                          MoaiIcons.discountLocation,
                                      },
                                      label: switch (action) {
                                        _Action.banks =>
                                          LocaleKeys.discounts_banks_title.tr(),
                                        _Action.merchants =>
                                          LocaleKeys.discounts_merchants_title
                                              .tr(),
                                        _Action.location =>
                                          LocaleKeys.discounts_location_title
                                              .tr(),
                                      },
                                      description: switch (action) {
                                        _Action.banks => _count(
                                          _service.selectedBankIds.length,
                                        ),
                                        _Action.merchants =>
                                          _service.hasSelectedMerchants
                                              ? _count(
                                                  _service
                                                      .selectedMerchantKeys
                                                      .length,
                                                )
                                              : LocaleKeys
                                                    .discounts_merchants_none_desc
                                                    .tr(),
                                        _Action.location =>
                                          weather?.locationDisplayName ?? '',
                                      },
                                      onPressed: () => switch (action) {
                                        _Action.banks =>
                                          TvDiscountBanksDialog.show(context),
                                        _Action.merchants =>
                                          TvDiscountMerchantsDialog.show(
                                            context,
                                          ),
                                        _Action.location =>
                                          TvWeatherLocationDialog.show(context),
                                      },
                                      onKeyLeft: widget.onKeyLeft,
                                      onKeyUp: onKeyUp,
                                      onKeyDown: onKeyDown,
                                    ),
                                  _RubroItem(:final rubro) =>
                                    TvSettingsSwitchRow(
                                      focusNode: focusNode,
                                      icon: DiscountFormat.rubroIcon(rubro),
                                      label: DiscountFormat.rubro(rubro),
                                      description:
                                          DiscountFormat.rubroDescription(
                                            rubro,
                                          ),
                                      value: _service.rubros.contains(rubro),
                                      onChanged: (_) =>
                                          _service.toggleRubro(rubro),
                                      onKeyLeft: widget.onKeyLeft,
                                      onKeyUp: onKeyUp,
                                      onKeyDown: onKeyDown,
                                    ),
                                },
                              ),
                        ),
                      ),
                    ),
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
