import 'package:flutter/material.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Ítem de grupo: mismo [TvIconListCard] que países / categorías.
class GroupCard extends StatelessWidget {
  static final Map<String, IconData> icons = {
    'favorite': MoaiIcons.favoriteOutline,
    'no_adults': MoaiIcons.explicitOutlined,
    'sports_soccer': MoaiIcons.sportsSoccerOutlined,
    'movie': MoaiIcons.movieOutlined,
    'child_hat': MoaiIcons.childCareOutlined,
    'newspaper': MoaiIcons.newspaperOutlined,
    'tv_gen': MoaiIcons.tvOutlined,
    'language': MoaiIcons.languageOutlined,
  };

  static IconData iconFor(String iconKey) =>
      icons[iconKey] ?? MoaiIcons.groupOutlined;

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

