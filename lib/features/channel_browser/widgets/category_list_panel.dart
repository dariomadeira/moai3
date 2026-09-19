import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/widgets/cards/category_card.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Panel Categorías: mismo diseño windowed de 6 que Países.
class CategoryListPanel extends StatefulWidget {
  final String title;
  final String selectedCountry;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  const CategoryListPanel({
    super.key,
    required this.title,
    required this.selectedCountry,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
  });

  @override
  State<CategoryListPanel> createState() => CategoryListPanelState();
}

class CategoryListPanelState extends State<CategoryListPanel> {
  final _listKey = GlobalKey<TvWindowedListState<String>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'category_empty');

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final idx = widget.categories.indexOf(widget.selectedCategory);
    if (idx >= 0) return idx;
    return 0;
  }

  /// Lo llama HomeTvArea (L/R paneles / alfabeto / returnFocus).
  void focusSelected() {
    if (widget.categories.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.categories.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant CategoryListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    const windowSize = 6;
    final listAlign = widget.categories.length < windowSize
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
            subtitle: 'browser_category_subtitle'.tr(
              namedArgs: {'country': widget.selectedCountry},
            ),
            showFilterText: widget.categories.length > 1,
          ),
          Expanded(
            child: widget.categories.isEmpty
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: Icons.category_outlined,
                    message: 'browser_categories_empty'.tr(),
                    onFocusUp: widget.onFocusUp,
                  )
                : Align(
                    alignment: listAlign,
                    child: TvWindowedList<String>(
                      key: _listKey,
                      items: widget.categories,
                      windowSize: windowSize,
                      initialGlobalIndex: _selectedIndex,
                      itemExtent: TvLayoutConstants.categoryItemHeight,
                      onFocusUpFromFirst: widget.onFocusUp,
                      itemBuilder: (
                        context,
                        category,
                        focusNode,
                        local,
                        global,
                        onKeyUp,
                        onKeyDown,
                      ) {
                        return CategoryCard(
                          key: ValueKey('category-$category'),
                          category: category,
                          isSelected: widget.selectedCategory == category,
                          focusNode: focusNode,
                          onLongPress: widget.onLongPress,
                          onKeyUp: onKeyUp,
                          onKeyDown: onKeyDown,
                          onTap: () => widget.onSelect(category),
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

