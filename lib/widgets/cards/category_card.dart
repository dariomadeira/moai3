import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/widgets/cards/tv_icon_list_card.dart';

/// Ítem de categoría: mismo [TvIconListCard] que países, con ícono por nombre.
class CategoryCard extends StatelessWidget {
  static const Map<String, IconData> icons = {
    'Aire': Symbols.airware,
    'Interior': Symbols.location_city,
    'Provinciales': Symbols.location_city,
    'Deportes': Icons.sports_soccer,
    'Noticias': Icons.newspaper,
    'Infantiles': Symbols.child_hat,
    'Infantil': Symbols.child_hat,
    'Entretenimiento': Symbols.confirmation_number,
    'Comedia': Icons.theater_comedy,
    'Reality': Symbols.visibility,
    'Anime': Symbols.animation,
    'Cocina': Icons.restaurant_menu,
    'Radios': Symbols.radio,
    'Series': Symbols.tv,
    'Películas': Symbols.movie,
    'Cine y Series': Symbols.movie,
    'Documentales': Symbols.library_books,
    'Música': Symbols.music_note,
    'Niños': Symbols.child_care,
    'Educación': Symbols.school,
    'Religión': Symbols.church,
    'Religioso': Symbols.church,
    'Conciertos': Symbols.music_note,
    'Telenovelas': Symbols.favorite,
    'Novelas': Symbols.favorite,
    'Cine': Symbols.movie,
    'Cultura': Symbols.book_2,
    'Cultural': Symbols.book_2,
    'General': Symbols.remote_gen,
    'Teleshows': Symbols.confirmation_number,
    'Otros': Symbols.more,
    'Internacional': Symbols.globe,
    'Comunitarios': Symbols.groups,
    'Culturales': Symbols.theaters,
    'Adultos': Symbols.lock,
  };

  static IconData iconFor(String category) =>
      icons[category] ?? Icons.tv_rounded;

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

