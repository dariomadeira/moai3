import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_grid_catalog.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// REDISEÑO (2026-11-01): tarjeta grande de películas del Inicio (dos
/// lugares de la lista): Interesantes y Seguir viendo. A la izquierda el
/// mismo encabezado que Arcade y, como es más alta, el botón para todas
/// abajo de todo; a la derecha las películas con el item de la grilla de
/// Películas, pero con una imagen horizontal (y, si se empezó, la barra de
/// lo visto).
///
/// Sin borde de foco: lo marca la película elegida o el botón. El foco y la
/// selección los maneja el Inicio: [selectedIndex] es la película elegida o
/// [actionIndex] para el botón (a la izquierda de la primera).
class HomeMovieBigCard extends StatelessWidget {
  const HomeMovieBigCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.countLabel,
    required this.actionIcon,
    required this.actionLabel,
    required this.movies,
    required this.selectedIndex,
    this.isFocused = false,
    this.watched = const {},
    this.loadingId,
  });

  /// Ícono del encabezado y su color (el de la tarjeta).
  final IconData icon;
  final Color color;
  final String title;

  /// Debajo del título: cuántas hay.
  final String countLabel;

  /// Botón para todas ("Quitar todas", "Marcar todo como visto").
  final IconData actionIcon;
  final String actionLabel;

  final List<MovieItem> movies;
  final int selectedIndex;
  final bool isFocused;

  /// Cuánto se vio de cada una (0–1, por `contentId`): la barra.
  final Map<String, double> watched;

  /// La que se está abriendo (`contentId`): muestra que carga.
  final String? loadingId;

  /// [selectedIndex] del botón.
  static const int actionIndex = -1;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return MoaiGlass(
      borderRadius: radius,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          // El botón queda a la misma distancia del borde de abajo que el
          // texto del de la izquierda (20): la tarjeta deja 14 arriba y
          // abajo para las películas, el encabezado suma 6.
          Container(
            width: HomeCardSummary.width,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _Header(
              icon: icon,
              color: color,
              title: title,
              countLabel: countLabel,
              actionIcon: actionIcon,
              actionLabel: actionLabel,
              showAction: movies.isNotEmpty,
              actionFocused: isFocused && selectedIndex == actionIndex,
            ),
          ),
          const HomeCardDivider(
            height: null,
            margin: EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: _Posters(
              movies: movies,
              selectedIndex: isFocused ? selectedIndex : -1,
              watched: watched,
              loadingId: loadingId,
            ),
          ),
        ],
      ),
    );
  }
}

/// La fila de películas, al alto de la tarjeta (en el TV entran 2). Se corre
/// para que la elegida siempre se vea y las flechas de los costados avisan
/// si hay más.
class _Posters extends StatelessWidget {
  const _Posters({
    required this.movies,
    required this.selectedIndex,
    required this.watched,
    this.loadingId,
  });

  final List<MovieItem> movies;
  final Map<String, double> watched;
  final String? loadingId;

  /// Película elegida; fuera de la lista (sin foco o en el botón), ninguna.
  final int selectedIndex;

  static const double _gap = 10;

  /// Cuántas entran por lo menos (en el TV, 2).
  static const int _minVisible = 2;

  @override
  Widget build(BuildContext context) {
    // Al quitar la última, hasta que el Inicio la saca.
    if (movies.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        // La imagen horizontal entera con su margen y la barra del nombre,
        // al alto de la tarjeta; si así no entran
        // [_minVisible], más chicas (y centradas en el alto).
        final tilesWidth = constraints.maxWidth - 2 * HomeEdgePill.width;
        // (Un pelo menos: que el redondeo no deje afuera la última.)
        final fitWidth =
            (tilesWidth - (_minVisible - 1) * _gap) / _minVisible - 0.01;
        final width = TvMovieCard.widthForHeight(
          constraints.maxHeight,
          wide: true,
        ).clamp(0.0, fitWidth);
        final height = TvMovieCard.heightForWidth(width, wide: true);
        final visible = ((tilesWidth + _gap) ~/ (width + _gap)).clamp(
          1,
          movies.length,
        );
        return HomeRowWindow(
          count: movies.length,
          visible: visible,
          selected: selectedIndex,
          builder: (start) => Row(
            children: [
              HomeEdgePill(icon: MoaiIcons.dpadLeft, active: start > 0),
              Expanded(
                child: Row(
                  // La primera arranca siempre donde arrancaría con la fila llena
                  // (centrada entre las flechas), aunque haya menos.
                  children: [
                    SizedBox(
                      width: HomeRowWindow.inset(
                        width: tilesWidth,
                        tileWidth: width,
                        gap: _gap,
                      ),
                    ),
                    for (var i = start; i < start + visible; i++) ...[
                      if (i > start) const SizedBox(width: _gap),
                      SizedBox(
                        width: width,
                        height: height,
                        child: RepaintBoundary(
                          child: TvMovieCard(
                            key: ValueKey(MovieGridCatalog.keyOf(movies[i])),
                            movie: movies[i],
                            isSelected: i == selectedIndex,
                            wide: true,
                            progress: watched[movies[i].contentId],
                            isLoading: movies[i].contentId == loadingId,
                            // OK y el toque los maneja el Inicio.
                            onTap: () {},
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              HomeEdgePill(
                icon: MoaiIcons.dpadRight,
                active: start + visible < movies.length,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Películas" + ícono y título en grande + cuántas hay, como el resumen
/// de Arcade; abajo de todo el botón para todas.
class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.color,
    required this.title,
    required this.countLabel,
    required this.actionIcon,
    required this.actionLabel,
    required this.showAction,
    required this.actionFocused,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String countLabel;
  final IconData actionIcon;
  final String actionLabel;
  final bool showAction;
  final bool actionFocused;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        HomeCardSummary(
          label: LocaleKeys.home_rail_movies_title.tr(),
          icon: icon,
          color: color,
          title: title,
          line: countLabel,
        ),
        const Spacer(),
        if (showAction)
          HomeGlassButton(
            icon: actionIcon,
            label: actionLabel,
            focused: actionFocused,
          ),
      ],
    );
  }
}
