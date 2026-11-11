import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Interesantes" del Inicio ([HomeMovieBigCard]): las películas marcadas
/// para ver, con "Quitar todas". Sólo sale con alguna película (sin ninguna
/// el Inicio no la muestra).
///
/// [selectedIndex] es la película elegida o [clearAllIndex]. OK abre el
/// detalle (mantener OK la quita) o, en el botón, confirma vaciar la lista.
class HomeWatchlistBigCard extends StatelessWidget {
  const HomeWatchlistBigCard({
    super.key,
    required this.movies,
    required this.selectedIndex,
    this.isFocused = false,
  });

  final List<MovieItem> movies;
  final int selectedIndex;
  final bool isFocused;

  /// [selectedIndex] del botón "Quitar todas".
  static const int clearAllIndex = HomeMovieBigCard.actionIndex;

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFFEA580C);

  @override
  Widget build(BuildContext context) {
    return HomeMovieBigCard(
      icon: MoaiIcons.vodWatchlist,
      color: color,
      title: LocaleKeys.home_watchlist_title.tr(),
      countLabel: movies.length == 1
          ? LocaleKeys.home_watchlist_to_watch_one.tr()
          : LocaleKeys.home_watchlist_to_watch.tr(
              namedArgs: {'count': '${movies.length}'},
            ),
      actionIcon: MoaiIcons.vodWatchlistRemove,
      actionLabel: LocaleKeys.home_watchlist_remove_all.tr(),
      movies: movies,
      selectedIndex: selectedIndex,
      isFocused: isFocused,
    );
  }
}
