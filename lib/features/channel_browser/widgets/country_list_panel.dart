import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/widgets/cards/country_card.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Panel Países: lista por ventana de 6 (sin ListView).
class CountryListPanel extends StatefulWidget {
  final String title;
  final List<String> countries;
  final String selectedCountry;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  const CountryListPanel({
    super.key,
    required this.title,
    required this.countries,
    required this.selectedCountry,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
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
    // Pocos ítems → arriba (junto al header). Ventana llena → abajo (margen inferior = lado).
    final listAlign = widget.countries.length < windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return Container(
      padding: const EdgeInsets.only(
        left: 4,
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
                    icon: Icons.grid_view_outlined,
                    message: 'browser_countries_empty'.tr(),
                    onFocusUp: widget.onFocusUp,
                  )
                : Align(
                    alignment: listAlign,
                    child: TvWindowedList<String>(
                      key: _listKey,
                      items: widget.countries,
                      windowSize: windowSize,
                      initialGlobalIndex: _selectedIndex,
                      itemExtent: TvLayoutConstants.countryItemHeight,
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
                        return CountryCard(
                          key: ValueKey('country-$country'),
                          country: country,
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

