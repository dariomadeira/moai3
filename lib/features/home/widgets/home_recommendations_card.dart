import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Recomendadas" del Inicio (SPEC-51): las películas que recomendaron los
/// amigos, como "Seguir viendo". Con una elegida, debajo del título dice
/// quién la recomendó.
class HomeRecommendationsCard extends StatelessWidget {
  const HomeRecommendationsCard({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.isFocused = false,
    this.series = false,
  });

  final List<FriendRecommendation> items;
  final int selectedIndex;
  final bool isFocused;

  /// La de series: "Series" arriba, su ícono y, sobre cada una, hasta qué
  /// temporada llegó quien la recomendó ("Hasta T3").
  final bool series;

  /// [selectedIndex] del botón "Borrar todas".
  static const int clearAllIndex = HomeMovieBigCard.actionIndex;

  static const Color color = Color(0xFFDB2777);

  String get _line {
    if (!isFocused || selectedIndex < 0 || selectedIndex >= items.length) {
      return LocaleKeys.home_recommendations_count.tr(
        namedArgs: {'count': '${items.length}'},
      );
    }
    final names = items[selectedIndex].names;
    return names.length == 1
        ? LocaleKeys.home_recommendations_from.tr(
            namedArgs: {'name': names.first},
          )
        : LocaleKeys.home_recommendations_from_many.tr(
            namedArgs: {'name': names.first, 'count': '${names.length - 1}'},
          );
  }

  @override
  Widget build(BuildContext context) {
    return HomeMovieBigCard(
      icon: MoaiIcons.vodRecommend,
      svgIcon: series ? MoaiIcons.seriesSvg : null,
      sectionLabel: series ? LocaleKeys.home_rail_series_title.tr() : null,
      badges: series
          ? {
              for (final item in items)
                if (item.seasonReached case final season?)
                  item.movie.contentId: LocaleKeys
                      .home_series_recommendations_until
                      .tr(namedArgs: {'season': '$season'}),
            }
          : const {},
      color: color,
      title: LocaleKeys.home_recommendations_title.tr(),
      countLabel: _line,
      actionIcon: MoaiIcons.delete,
      actionLabel: LocaleKeys.home_recommendations_clear.tr(),
      movies: [for (final item in items) item.movie],
      selectedIndex: selectedIndex,
      isFocused: isFocused,
    );
  }
}
