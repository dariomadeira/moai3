import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Seguir series" del Inicio ([HomeMovieBigCard], como "Seguir" de
/// películas): una por serie, la última vista primero, con el capítulo a
/// ver en la etiqueta ("T2 · Cap. 5" o, si se terminó el anterior,
/// "Sigue: T2 · Cap. 6") y la barra si quedó a la mitad. Sólo se muestra si
/// hay alguna; eso lo decide el Inicio.
///
/// OK abre el detalle de la serie con el foco en ese capítulo; mantener OK
/// quita la serie de la tarjeta; el botón, todas.
class HomeSeriesContinueCard extends StatelessWidget {
  const HomeSeriesContinueCard({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.isFocused = false,
  });

  final List<SeriesContinueItem> items;
  final int selectedIndex;
  final bool isFocused;

  /// [selectedIndex] del botón "Quitar todas".
  static const int clearAllIndex = HomeMovieBigCard.actionIndex;

  /// La serie como película para la tarjeta (su `contentId` es la serie).
  static MovieItem movieOf(SeriesContinueItem item) => MovieItem(
    contentId: item.entry.seriesKey,
    name: item.entry.title,
    poster: item.entry.poster,
    backdrops: item.entry.backdrops,
    programType: 'teleplay',
  );

  /// "T2 · Cap. 5" o "Sigue: T2 · Cap. 6".
  static String badgeOf(SeriesContinueItem item) =>
      (item.isNext
              ? LocaleKeys.home_series_continue_next
              : LocaleKeys.home_series_continue_episode)
          .tr(
            namedArgs: {
              'season': '${item.episode.seasonNumber}',
              'episode': '${item.episode.episodeNumber}',
            },
          );

  @override
  Widget build(BuildContext context) {
    return HomeMovieBigCard(
      icon: MoaiIcons.vodResume,
      svgIcon: MoaiIcons.seriesSvg,
      color: TvVerticalNavRail.seriesColor,
      sectionLabel: LocaleKeys.home_rail_series_title.tr(),
      title: LocaleKeys.home_series_continue_title.tr(),
      countLabel: LocaleKeys.home_series_continue_count.tr(
        namedArgs: {'count': '${items.length}'},
      ),
      actionIcon: MoaiIcons.delete,
      actionLabel: LocaleKeys.home_series_continue_clear.tr(),
      movies: [for (final item in items) movieOf(item)],
      selectedIndex: selectedIndex,
      isFocused: isFocused,
      watched: {for (final item in items) item.entry.seriesKey: ?item.progress},
      badges: {for (final item in items) item.entry.seriesKey: badgeOf(item)},
    );
  }
}
