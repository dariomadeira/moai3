import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Marcadas" de series en el Inicio ([HomeMovieBigCard], como la de
/// películas): las series marcadas para ver después, con "Desmarcar todas".
/// Sólo sale con alguna (eso lo decide el Inicio).
///
/// OK abre el detalle de la serie (mantener OK la desmarca); el botón
/// confirma vaciar la lista.
class HomeSeriesWatchlistCard extends StatelessWidget {
  const HomeSeriesWatchlistCard({
    super.key,
    required this.series,
    required this.selectedIndex,
    this.isFocused = false,
  });

  final List<MovieItem> series;
  final int selectedIndex;
  final bool isFocused;

  /// [selectedIndex] del botón "Desmarcar todas".
  static const int clearAllIndex = HomeMovieBigCard.actionIndex;

  @override
  Widget build(BuildContext context) {
    return HomeMovieBigCard(
      icon: MoaiIcons.vodWatchlist,
      svgIcon: MoaiIcons.seriesSvg,
      color: TvVerticalNavRail.seriesColor,
      sectionLabel: LocaleKeys.home_rail_series_title.tr(),
      title: LocaleKeys.home_watchlist_title.tr(),
      countLabel: series.length == 1
          ? LocaleKeys.home_watchlist_to_watch_one.tr()
          : LocaleKeys.home_watchlist_to_watch.tr(
              namedArgs: {'count': '${series.length}'},
            ),
      actionIcon: MoaiIcons.vodWatchlistRemove,
      actionLabel: LocaleKeys.home_watchlist_remove_all.tr(),
      movies: series,
      selectedIndex: selectedIndex,
      isFocused: isFocused,
    );
  }
}
