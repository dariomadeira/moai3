import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';

/// Ítem de país/grupo: [TvIconListCard] con ícono HugeIcons strokeRoundedTvMinimalPlay.
class CountryCard extends StatelessWidget {
  final String country;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onLongPress;

  const CountryCard({
    super.key,
    required this.country,
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
      label: country,
      hugeIcon: HugeIcons.strokeRoundedTvMinimalPlay,
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
