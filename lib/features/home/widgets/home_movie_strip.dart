import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/image_decode.dart';

/// Fila de películas de las tarjetas del Inicio (Interesantes, Adelantos),
/// con ventana como la de Eventos: se corre para que la elegida siempre se
/// vea y las flechas avisan si hay más de un lado.
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

  /// Cuánto se vio de cada película (0–1, por `contentId`): una barra fina
  /// abajo de la miniatura. Sin dato, sin barra.
  final Map<String, double> watched;

  /// Las miniaturas van 16:9 al alto de la tarjeta (en el TV, unos 79
  /// puntos); sin alto conocido, este.
  static const double _defaultTileHeight = 108;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : _defaultTileHeight;
        final tileWidth = tileHeight * 16 / 9;
        final step = tileWidth + _tileGap;
        final tilesWidth = constraints.maxWidth - 2 * _Edge.width;
        final visible = ((tilesWidth + _tileGap) ~/ step).clamp(
          1,
          movies.length,
        );
        final selected = selectedIndex.clamp(0, movies.length - 1);
        final start = (selected - visible + 1).clamp(
          0,
          movies.length - visible,
        );

        return Row(
          children: [
            _Edge(icon: MoaiIcons.dpadLeft, active: start > 0),
            Expanded(
              child: Row(
                children: [
                  for (var i = start; i < start + visible; i++) ...[
                    if (i > start) const SizedBox(width: _tileGap),
                    SizedBox(
                      width: tileWidth,
                      height: tileHeight,
                      child: _MovieTile(
                        movie: movies[i],
                        width: tileWidth,
                        height: tileHeight,
                        isFocused: isFocused && i == selectedIndex,
                        watched: watched[movies[i].contentId] ?? 0,
                        isLoading: movies[i].contentId == loadingId,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Edge(
              icon: MoaiIcons.dpadRight,
              active: start + visible < movies.length,
            ),
          ],
        );
      },
    );
  }
}

/// Flecha de un costado de la fila, como en Eventos.
class _Edge extends StatelessWidget {
  const _Edge({required this.icon, required this.active});

  static const double width = 28;

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: width,
      child: Icon(
        icon,
        size: MoaiIconSizes.lg,
        color: active
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Una película: su imagen horizontal con el título encima. Con foco, borde
/// del acento pintado sobre la foto (como la Hero del detalle). Un adelanto
/// va con su nombre sin la marca "(Tráiler)" del catálogo.
class _MovieTile extends StatelessWidget {
  const _MovieTile({
    required this.movie,
    required this.width,
    required this.height,
    required this.isFocused,
    this.watched = 0,
    this.isLoading = false,
  });

  final MovieItem movie;
  final bool isFocused;

  /// Tamaño de la miniatura: la foto se decodifica a esto.
  final double width;
  final double height;

  /// Se está pidiendo el video: velo oscuro con un indicador.
  final bool isLoading;

  /// Cuánto se vio (0–1); 0 sin barra.
  final double watched;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final imageUrl = movie.stageImages.isNotEmpty
        ? movie.stageImages.first
        : movie.poster;
    final placeholder = ColoredBox(
      color: Colors.white.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          MoaiIcons.vodMovie,
          size: MoaiIconSizes.lg,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused
              ? scheme.primary
              : Colors.white.withValues(alpha: 0.10),
          width: isFocused ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl == null || imageUrl.trim().isEmpty)
              placeholder
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                // Los fondos vienen de hasta 4096 px: se decodifican al
                // tamaño de la miniatura (si no, ocupan 8–28 MB cada uno).
                memCacheWidth: coverDecodeWidth(
                  width: width,
                  height: height,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xB3000000)],
                  stops: [0.35, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              // Con barra, el nombre sube para dejarle lugar.
              bottom: watched > 0 ? 18 : 8,
              child: Text(
                movie.isTrailer
                    ? MovieItem.withoutTrailerTag(movie.name)
                    : movie.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  color: Colors.white,
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Hasta dónde se vio: una línea fina flotando dentro de la foto,
            // separada del borde (con foco, el borde es del mismo acento).
            if (watched > 0)
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.25),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: watched.clamp(0.0, 1.0),
                      child: ColoredBox(color: scheme.primary),
                    ),
                  ),
                ),
              ),
            if (isLoading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.55),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
