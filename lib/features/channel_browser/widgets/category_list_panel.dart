import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel Categorías: el mismo diseño que Grupos (encabezado con degradado,
/// fichas que llenan el alto y los estados del rail en el acento).
class CategoryListPanel extends StatefulWidget {
  final String title;
  final String selectedCountry;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  /// Categoría del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedCategory;

  const CategoryListPanel({
    super.key,
    required this.title,
    required this.selectedCountry,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
    this.tunedCategory,
  });

  @override
  State<CategoryListPanel> createState() => CategoryListPanelState();
}

class CategoryListPanelState extends State<CategoryListPanel>
    implements FocusSelectable {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _listKey = GlobalKey<TvWindowedListState<String>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'category_empty');
  int? _focusedIndex;

  /// Alto mínimo de cada lugar: ficha de 48 más la separación.
  static const double _minItemExtent = 48 + TvPanelSlots.gap;

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_focusedIndex != null && _focusedIndex! < widget.categories.length) {
      return _focusedIndex!;
    }
    final idx = widget.categories.indexOf(widget.selectedCategory);
    if (idx >= 0) return idx;
    return 0;
  }

  /// Lo llama HomeTvArea (L/R paneles / alfabeto / returnFocus).
  @override
  void focusSelected() {
    if (widget.categories.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.categories.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant CategoryListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _focusedIndex = null;
    }
    if (oldWidget.selectedCategory != widget.selectedCategory &&
        widget.categories.isNotEmpty) {
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
            title: LocaleKeys.browser_category_title.tr(),
            subtitle: widget.categories.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : LocaleKeys.browser_category_subtitle.tr(),
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: widget.categories.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: TvEmptyStateCard(
                      focusNode: _emptyFocusNode,
                      icon: MoaiIcons.tvAccordionCategorias,
                      message: LocaleKeys.browser_categories_empty.tr(),
                      onFocusUp: widget.onFocusUp,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Entran tantas fichas como quepan enteras y se
                      // estiran para llenar el alto (como en Grupos).
                      final height = constraints.maxHeight;
                      final windowSize = (height / _minItemExtent)
                          .floor()
                          .clamp(1, 64);
                      final itemExtent = height / windowSize;
                      return TvWindowedList<String>(
                        key: _listKey,
                        items: widget.categories,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        onFocusUpFromFirst: widget.onFocusUp,
                        onFocusedGlobalIndex: (idx) {
                          _focusedIndex = idx;
                        },
                        itemBuilder:
                            (
                              context,
                              category,
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
                                  key: ValueKey('category-$category'),
                                  label: category,
                                  icon: MoaiIcons.tvCategoryIconFor(category),
                                  isSelected: widget.tunedCategory == category,
                                  focusNode: focusNode,
                                  onLongPress: widget.onLongPress,
                                  onKeyUp: onKeyUp,
                                  onKeyDown: onKeyDown,
                                  onTap: () => widget.onSelect(category),
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
