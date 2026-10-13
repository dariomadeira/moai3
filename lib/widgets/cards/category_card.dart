import 'package:flutter/material.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Ítem de categoría: mismo [TvIconListCard] que países, con ícono por nombre.
class CategoryCard extends StatelessWidget {
  static const Map<String, IconData> icons = {
    'Aire': MoaiIcons.airware,
    'Interior': MoaiIcons.locationCity,
    'Provinciales': MoaiIcons.locationCity,
    'Deportes': MoaiIcons.sportsSoccerOutlined,
    'Noticias': MoaiIcons.newspaperOutlined,
    'Infantiles': MoaiIcons.childHat,
    'Infantil': MoaiIcons.childHat,
    'Entretenimiento': MoaiIcons.confirmationNumber,
    'Comedia': MoaiIcons.theaterComedyOutlined,
    'Reality': MoaiIcons.visibility,
    'Anime': MoaiIcons.animation,
    'Cocina': MoaiIcons.restaurantMenuOutlined,
    'Radios': MoaiIcons.radio,
    'Series': MoaiIcons.symbolTv,
    'Películas': MoaiIcons.movie,
    'Cine y Series': MoaiIcons.movie,
    'Documentales': MoaiIcons.libraryBooks,
    'Música': MoaiIcons.musicNote,
    'Niños': MoaiIcons.childCare,
    'Educación': MoaiIcons.school,
    'Religión': MoaiIcons.church,
    'Religioso': MoaiIcons.church,
    'Conciertos': MoaiIcons.musicNote,
    'Telenovelas': MoaiIcons.symbolFavorite,
    'Novelas': MoaiIcons.symbolFavorite,
    'Cine': MoaiIcons.movie,
    'Cultura': MoaiIcons.book2,
    'Cultural': MoaiIcons.book2,
    'General': MoaiIcons.remoteGen,
    'Teleshows': MoaiIcons.confirmationNumber,
    'Otros': MoaiIcons.more,
    'Internacional': MoaiIcons.globe,
    'Comunitarios': MoaiIcons.groups,
    'Culturales': MoaiIcons.theaters,
    'Adultos': MoaiIcons.lock,
  };

  static IconData iconFor(String category) =>
      icons[category] ?? MoaiIcons.tvOutlined;

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

