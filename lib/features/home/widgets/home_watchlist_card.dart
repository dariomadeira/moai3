import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/features/home/widgets/home_movie_list_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Widget "Interesantes" del Inicio: las películas marcadas para ver, con
/// el botón "Quitar todas". Sin películas explica cómo agregarlas.
///
/// El foco y la selección los maneja el Inicio: [selectedIndex] es la
/// película elegida o el botón (←/→ lo mueven). OK abre el detalle de la
/// película (mantener OK la quita) o, en el botón, confirma vaciar la lista.
class HomeWatchlistCard extends StatelessWidget {
  const HomeWatchlistCard({
    super.key,
    required this.movies,
    required this.selectedIndex,
    this.isFocused = false,
  });

  /// Sin empezar: las empezadas pasan a "Seguir viendo".
  final List<MovieItem> movies;

  /// Película elegida, o [clearAllIndex] para el botón "Quitar todas".
  final int selectedIndex;
  final bool isFocused;

  /// [selectedIndex] del botón "Quitar todas" (a la izquierda de la primera).
  static const int clearAllIndex = HomeMovieListCard.actionIndex;

  @override
  Widget build(BuildContext context) {
    final count = movies.length;
    return HomeMovieListCard(
      icon: MoaiIcons.vodWatchlist,
      glow: HomeCardColors.watchlist,
      title: LocaleKeys.home_watchlist_title.tr(),
      countLabel: count == 1
          ? LocaleKeys.home_watchlist_count_one.tr()
          : LocaleKeys.home_watchlist_count.tr(namedArgs: {'count': '$count'}),
      hint: LocaleKeys.home_watchlist_hint.tr(),
      actionIcon: MoaiIcons.delete,
      actionLabel: LocaleKeys.home_watchlist_remove_all.tr(),
      emptyText: LocaleKeys.home_watchlist_empty.tr(),
      movies: movies,
      selectedIndex: selectedIndex,
      isFocused: isFocused,
    );
  }
}
