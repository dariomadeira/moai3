import 'package:flutter/material.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';

/// Ítem de categoría: mismo [TvIconListCard] que países, con ícono por nombre.
class CategoryCard extends StatelessWidget {
  static const Map<String, List<List<dynamic>>> icons = {
    'Aire': AppIcons.tv,
    'Interior': AppIcons.globe,
    'Provinciales': AppIcons.globe,
    'Deportes': AppIcons.arcade,
    'Noticias': AppIcons.info,
    'Infantiles': AppIcons.star,
    'Infantil': AppIcons.star,
    'Entretenimiento': AppIcons.category,
    'Comedia': AppIcons.category,
    'Reality': AppIcons.tv,
    'Anime': AppIcons.star,
    'Cocina': AppIcons.category,
    'Radios': AppIcons.voiceTest,
    'Series': AppIcons.tv,
    'Películas': AppIcons.tv,
    'Cine y Series': AppIcons.tv,
    'Documentales': AppIcons.info,
    'Música': AppIcons.voiceTest,
    'Niños': AppIcons.star,
    'Educación': AppIcons.info,
    'Religión': AppIcons.info,
    'Religioso': AppIcons.info,
    'Conciertos': AppIcons.voiceTest,
    'Telenovelas': AppIcons.star,
    'Novelas': AppIcons.star,
    'Cine': AppIcons.tv,
    'Cultura': AppIcons.info,
    'Cultural': AppIcons.info,
    'General': AppIcons.category,
    'Teleshows': AppIcons.tv,
    'Otros': AppIcons.category,
    'Internacional': AppIcons.globe,
    'Comunitarios': AppIcons.group,
    'Culturales': AppIcons.info,
    'Adultos': AppIcons.lock,
  };

  static List<List<dynamic>> iconFor(String category) =>
      icons[category] ?? AppIcons.tv;

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

