import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/features/channel_browser/country_flag_assets.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_fixed_window_viewport.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel Países: lista por ventana de 6 (sin ListView).
class CountryListPanel extends StatefulWidget {
  final String title;
  final List<String> countries;
  final Map<String, String> countryFlags;
  final String selectedCountry;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

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
    this.emptyMessage,
  });

  @override
  State<CountryListPanel> createState() => CountryListPanelState();
}

class CountryListPanelState extends State<CountryListPanel> {
  final _listKey = GlobalKey<TvWindowedListState<String>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'country_empty');

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final idx = widget.countries.indexOf(widget.selectedCountry);
    if (idx >= 0) return idx;
    return 0;
  }

  /// Lo llama HomeTvArea (rail → / ← desde categorías / alfabeto).
  void focusSelected() {
    if (widget.countries.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.countries.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant CountryListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    const windowSize = 6;
    const itemExtent = TvLayoutConstants.countryItemHeight;

    return Container(
      padding: const EdgeInsets.only(
        right: 12,
        top: 8,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelListHeader(
            subtitle: 'browser_country_subtitle'.tr(),
            showFilterText: widget.countries.length > 1,
          ),
          Expanded(
            child: widget.countries.isEmpty
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: MoaiIcons.tvAccordionGrupos,
                    message: widget.emptyMessage ?? 'browser_countries_empty'.tr(),
                    onFocusUp: widget.onFocusUp,
                  )
                : TvFixedWindowViewport(
                    slotCount: windowSize,
                    slotExtent: itemExtent,
                    child: TvWindowedList<String>(
                      key: _listKey,
                      items: widget.countries,
                      initialGlobalIndex: _selectedIndex,
                      showScrollDots: true,
                      focusOnMount: false,
                      onFocusUpFromFirst: widget.onFocusUp,
                      itemBuilder: (
                        context,
                        country,
                        focusNode,
                        local,
                        global,
                        onKeyUp,
                        onKeyDown,
                      ) {
                        return TvIconListCard(
                          key: ValueKey('country-$country'),
                          label: country,
                          icon: MoaiIcons.tvDisplays,
                          leading: CountryFlagAssets.leadingFor(
                            country,
                            flagUrl: widget.countryFlags[country],
                          ),
                          isSelected: widget.selectedCountry == country,
                          focusNode: focusNode,
                          onLongPress: widget.onLongPress,
                          onKeyUp: onKeyUp,
                          onKeyDown: onKeyDown,
                          onTap: () => widget.onSelect(country),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
