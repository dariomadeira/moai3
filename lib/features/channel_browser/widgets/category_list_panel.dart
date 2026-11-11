import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_group_list_panel.dart';

typedef CategoryListPanelState = TvGroupListPanelState<String>;

/// Panel Categorías: el mismo diseño que Grupos y Marcadores.
class CategoryListPanel extends TvGroupListPanel<String> {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;

  /// Categoría del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedCategory;

  const CategoryListPanel({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
    required this.onLongPress,
    super.onFocusUp,
    this.tunedCategory,
  });

  @override
  List<String> get items => categories;

  @override
  int get selectedIndex => categories.indexOf(selectedCategory);

  @override
  bool selectionChanged(CategoryListPanel old) =>
      old.selectedCategory != selectedCategory;

  @override
  String get title => LocaleKeys.browser_category_title.tr();

  @override
  String get subtitle => LocaleKeys.browser_category_subtitle.tr();

  @override
  IconData get emptyIcon => MoaiIcons.tvAccordionCategorias;

  @override
  String get emptyMessage => LocaleKeys.browser_categories_empty.tr();

  @override
  String get debugName => 'category';

  @override
  Widget buildTile(
    BuildContext context,
    String category,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) => TvGroupTile(
    key: ValueKey('category-$category'),
    label: category,
    icon: MoaiIcons.tvCategoryIconFor(category),
    isSelected: tunedCategory == category,
    focusNode: focusNode,
    onLongPress: onLongPress,
    onKeyUp: onKeyUp,
    onKeyDown: onKeyDown,
    onTap: () => onSelect(category),
  );
}
