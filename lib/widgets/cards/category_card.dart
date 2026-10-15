import 'package:flutter/material.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Ítem de categoría: mismo [TvIconListCard] que países, con ícono por nombre.
///
/// Los iconos viven agrupados en [MoaiIcons] (`tvCategory*` / [MoaiIcons.tvCategoryIcons]).
class CategoryCard extends StatelessWidget {
  /// Alias del mapa canónico en [MoaiIcons.tvCategoryIcons].
  static const Map<String, IconData> icons = MoaiIcons.tvCategoryIcons;

  static IconData iconFor(String category) =>
      MoaiIcons.tvCategoryIconFor(category);

  final String category;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onLongPress;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return TvIconListCard(
      label: category,
      icon: iconFor(category),
      isSelected: isSelected,
      onTap: onTap,
      focusNode: focusNode,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      onLongPress: onLongPress,
    );
  }
}
