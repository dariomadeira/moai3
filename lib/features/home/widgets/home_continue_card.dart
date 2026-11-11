import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Seguir viendo" del Inicio ([HomeMovieBigCard], como Interesantes): las
/// películas empezadas que se pueden retomar (la última vista primero), cada
/// una con la barra de lo visto, y el botón "Marcar todo como visto". Sólo
/// se muestra si hay alguna; eso lo decide el Inicio.
///
/// [selectedIndex] es la película elegida o [markAllIndex]. OK retoma la
/// película donde quedó (mantener OK la marca como vista) o, en el botón,
/// confirma marcarlas todas.
class HomeContinueCard extends StatelessWidget {
  const HomeContinueCard({
    super.key,
    required this.movies,
    required this.selectedIndex,
    required this.watched,
    this.isFocused = false,
    this.loadingId,
  });

  /// La que se está abriendo (`contentId`): muestra que carga.
  final String? loadingId;

  final List<MovieItem> movies;
  final int selectedIndex;
  final bool isFocused;

  /// Cuánto se vio de cada una (0–1, por `contentId`).
  final Map<String, double> watched;

  /// [selectedIndex] del botón "Marcar todo como visto".
  static const int markAllIndex = HomeMovieBigCard.actionIndex;

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return HomeMovieBigCard(
      icon: MoaiIcons.vodResume,
      color: color,
      title: LocaleKeys.home_continue_title.tr(),
      countLabel: LocaleKeys.home_continue_count.tr(
        namedArgs: {'count': '${movies.length}'},
      ),
      actionIcon: MoaiIcons.vodWatched,
      actionLabel: LocaleKeys.home_continue_mark_all.tr(),
      movies: movies,
      selectedIndex: selectedIndex,
      isFocused: isFocused,
      watched: watched,
      loadingId: loadingId,
    );
  }
}
