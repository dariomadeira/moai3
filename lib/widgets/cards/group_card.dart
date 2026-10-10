import 'package:flutter/material.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';

/// Ítem de grupo: mismo [TvIconListCard] que países / categorías.
class GroupCard extends StatelessWidget {
  static const Map<String, List<List<dynamic>>> icons = {
    'favorite': AppIcons.star,
    'no_adults': AppIcons.lock,
    'sports_soccer': AppIcons.arcade,
    'movie': AppIcons.tv,
    'child_hat': AppIcons.star,
    'newspaper': AppIcons.info,
    'tv_gen': AppIcons.tv,
    'language': AppIcons.globe,
  };

  static List<List<dynamic>> iconFor(String iconKey) =>
      icons[iconKey] ?? AppIcons.group;

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
      hugeIcon: iconFor(iconKey),
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

