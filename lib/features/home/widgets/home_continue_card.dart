import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/features/home/widgets/home_movie_list_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Widget "Seguir viendo" del Inicio: las películas empezadas que se pueden
/// retomar (la última vista primero), cada una con su barra de progreso, y
/// el botón "Marcar todo como visto". Sólo se muestra si hay alguna; eso lo
/// decide el Inicio.
///
/// El foco y la selección los maneja el Inicio: [selectedIndex] es la
/// película elegida o [markAllIndex] para el botón. OK retoma la película
/// donde quedó (mantener OK la marca como vista) o, en el botón, confirma
/// marcarlas todas.
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
  static const int markAllIndex = HomeMovieListCard.actionIndex;

  @override
  Widget build(BuildContext context) {
    final count = movies.length;
    return HomeMovieListCard(
      icon: MoaiIcons.vodResume,
      glow: HomeCardColors.continueWatching,
      title: LocaleKeys.home_continue_title.tr(),
      countLabel: count == 1
          ? LocaleKeys.home_watchlist_count_one.tr()
          : LocaleKeys.home_watchlist_count.tr(namedArgs: {'count': '$count'}),
      hint: LocaleKeys.home_continue_hint.tr(),
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
