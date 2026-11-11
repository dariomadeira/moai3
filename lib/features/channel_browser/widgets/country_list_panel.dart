import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/channel_browser/country_flag_assets.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel Grupos (países): encabezado y fichas como los paneles de Ajustes
/// (6 lugares que reparten el alto bajo el encabezado) y los estados del
/// rail en el acento.
class CountryListPanel extends StatefulWidget {
  final String title;
  final List<String> countries;
  final Map<String, String> countryFlags;
  final String selectedCountry;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  /// Grupo del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedCountry;

  /// Mensaje del estado vacío; por defecto "sin grupos". Se usa para mostrar
  /// un error de carga de plugins.
  final String? emptyMessage;

  const CountryListPanel({
    super.key,
    required this.title,
    required this.countries,
    this.countryFlags = const {},
    required this.selectedCountry,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
    this.tunedCountry,
    this.emptyMessage,
  });

  @override
  State<CountryListPanel> createState() => CountryListPanelState();
}

class CountryListPanelState extends State<CountryListPanel>
    implements FocusSelectable {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _listKey = GlobalKey<TvWindowedListState<String>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'country_empty');
  int? _focusedIndex;

  /// Alto mínimo de cada lugar: ficha de 48 más la separación.
  static const double _minItemExtent = 48 + TvPanelSlots.gap;

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_focusedIndex != null && _focusedIndex! < widget.countries.length) {
      return _focusedIndex!;
    }
    final idx = widget.countries.indexOf(widget.selectedCountry);
    if (idx >= 0) return idx;
    return 0;
  }

  /// Lo llama HomeTvArea (rail → / ← desde categorías / alfabeto).
  @override
  void focusSelected() {
    if (widget.countries.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.countries.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant CountryListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCountry != widget.selectedCountry) {
      _focusedIndex = null;
    }
    if (oldWidget.selectedCountry != widget.selectedCountry &&
        widget.countries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _listKey.currentState?.ensureVisible(
          _selectedIndex,
          requestFocus: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: TvPanelSlots.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: LocaleKeys.browser_country_title.tr(),
            subtitle: widget.countries.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : LocaleKeys.browser_country_subtitle.tr(),
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: widget.countries.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: TvEmptyStateCard(
                      focusNode: _emptyFocusNode,
                      icon: MoaiIcons.tvAccordionGrupos,
                      message:
                          widget.emptyMessage ??
                          LocaleKeys.browser_countries_empty.tr(),
                      onFocusUp: widget.onFocusUp,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Entran tantas fichas como quepan enteras y se
                      // estiran para llenar el alto: nunca quedan cortadas
                      // ni con hueco abajo.
                      final height = constraints.maxHeight;
                      final windowSize = (height / _minItemExtent)
                          .floor()
                          .clamp(1, 64);
                      final itemExtent = height / windowSize;
                      return TvWindowedList<String>(
                        key: _listKey,
                        items: widget.countries,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        focusOnMount: false,
                        onFocusUpFromFirst: widget.onFocusUp,
                        onFocusedGlobalIndex: (idx) {
                          _focusedIndex = idx;
                        },
                        itemBuilder:
                            (
                              context,
                              country,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: TvPanelSlots.gap / 2,
                                ),
                                child: TvGroupTile(
                                  key: ValueKey('country-$country'),
                                  label: country,
                                  icon: MoaiIcons.tvCountryItem,
                                  leading: CountryFlagAssets.leadingFor(
                                    country,
                                    flagUrl: widget.countryFlags[country],
                                  ),
                                  isSelected: widget.tunedCountry == country,
                                  focusNode: focusNode,
                                  onLongPress: widget.onLongPress,
                                  onKeyUp: onKeyUp,
                                  onKeyDown: onKeyDown,
                                  onTap: () => widget.onSelect(country),
                                ),
                              );
                            },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
