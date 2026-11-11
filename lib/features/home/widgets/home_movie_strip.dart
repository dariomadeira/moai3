import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_grid_catalog.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Fila de películas de las tarjetas del Inicio (Adelantos), con ventana
/// como la de Eventos: se corre para que la elegida siempre se vea y las
/// flechas avisan si hay más de un lado.
///
/// REDISEÑO: cada película es el item de Interesantes ([TvMovieCard] con
/// imagen horizontal): cristal, borde del acento con foco y el nombre abajo.
///
/// [selectedIndex] fuera de la lista (p. ej. un botón de la tarjeta) no
/// marca ninguna película.
class HomeMovieStrip extends StatelessWidget {
  const HomeMovieStrip({
    super.key,
    required this.movies,
    required this.selectedIndex,
    required this.isFocused,
    this.watched = const {},
    this.loadingId,
  });

  /// Película que se está abriendo (`contentId`): su miniatura muestra que
  /// carga.
  final String? loadingId;

  final List<MovieItem> movies;
  final int selectedIndex;
  final bool isFocused;

  /// Cuánto se vio de cada película (0–1, por `contentId`): la barra de
  /// [TvMovieCard]. Sin dato, sin barra.
  final Map<String, double> watched;

  /// Las tarjetas van al alto de la fila (la imagen 16:9 entera más el
  /// nombre); sin alto conocido, este.
  static const double _defaultTileHeight = 108;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : _defaultTileHeight;
        final tileWidth = TvMovieCard.widthForHeight(tileHeight, wide: true);
        final step = tileWidth + _tileGap;
        final tilesWidth = constraints.maxWidth - 2 * HomeEdgePill.width;
        final visible = ((tilesWidth + _tileGap) ~/ step).clamp(
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
                        tileWidth: tileWidth,
                        gap: _tileGap,
                      ),
                    ),
                    for (var i = start; i < start + visible; i++) ...[
                      if (i > start) const SizedBox(width: _tileGap),
                      SizedBox(
                        width: tileWidth,
                        height: tileHeight,
                        child: RepaintBoundary(
                          child: TvMovieCard(
                            key: ValueKey(MovieGridCatalog.keyOf(movies[i])),
                            movie: movies[i],
                            isSelected: isFocused && i == selectedIndex,
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
