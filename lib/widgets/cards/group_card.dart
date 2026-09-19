import 'package:flutter/material.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';

/// Ítem de grupo: mismo [TvIconListCard] que países / categorías.
class GroupCard extends StatelessWidget {
  static final Map<String, IconData> icons = {
    'favorite': Icons.favorite,
    'no_adults': Icons.explicit,
    'sports_soccer': Icons.sports_soccer,
    'movie': Icons.movie,
    'child_hat': Icons.child_care,
    'newspaper': Icons.newspaper,
    'tv_gen': Icons.tv,
    'language': Icons.language,
  };

  static IconData iconFor(String iconKey) => icons[iconKey] ?? Icons.group;

  final String groupName;
  final String iconKey;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const GroupCard({
    super.key,
    required this.groupName,
    required this.iconKey,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  Widget build(BuildContext context) {
    return TvIconListCard(
      label: groupName,
      icon: iconFor(iconKey),
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

