import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/models/torrent_stream.dart';
import 'package:moai3/state/movie_provider.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/dialogs/tv_movie_detail_dialog.dart';
import 'package:moai3/widgets/lists/tv_fixed_window_viewport.dart';
import 'package:moai3/widgets/lists/tv_windowed_grid.dart';

/// Área principal del catálogo de películas VOD envuelta en panel acordeón
/// con navegación D-Pad por ventana fija (TvFixedWindowViewport + TvWindowedGrid) (SPEC-38).
class HomeMoviesArea extends StatefulWidget {
  final FocusNode? moviesFocusNode;
  final VoidCallback onExitLeft;
  final ValueChanged<TorrentStream>? onPlayStream;

  const HomeMoviesArea({
    super.key,
    this.moviesFocusNode,
    required this.onExitLeft,
    this.onPlayStream,
  });

  static const icons = [
    Icons.local_movies_outlined,
  ];

  @override
  State<HomeMoviesArea> createState() => HomeMoviesAreaState();
}

class HomeMoviesAreaState extends State<HomeMoviesArea> {
  static const int _crossAxisCount = 5;
  static const int _windowSize = 10;
  static const int _rowCount = _windowSize ~/ _crossAxisCount;

  final _listKey = GlobalKey<TvWindowedGridState<Movie>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');

  void focusGrid() {
    if (!mounted) return;
    final provider = context.read<MovieProvider>();
    if (provider.movies.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(0, requestFocus: true);
  }

  void requestEntryFocus() => focusGrid();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<MovieProvider>();
        if (provider.movies.isEmpty && !provider.isLoading) {
          provider.loadPopularMovies();
        }
      }
    });
  }

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  void _openMovieDetail(Movie movie) {
    TvMovieDetailDialog.show(
      context,
      movie,
      onPlayStream: widget.onPlayStream,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<MovieProvider>();
    final movies = provider.movies;

    final panelColors = [
      scheme.surface,
    ];

    final titles = [
      'movies_panel_disponibles_title'.tr(),
    ];

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: panelColors,
      titles: titles,
      icons: HomeMoviesArea.icons,
      onPanelTap: (index) {},
      buildExpandedContent: (index, title) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () =>
                      context.read<MovieProvider>().loadPopularMovies(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        if (movies.isEmpty) {
          return TvEmptyStateCard(
            focusNode: _emptyFocusNode,
            icon: Symbols.hourglass_empty,
            message: 'No hay películas disponibles en el catálogo.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            // Distribuir el espacio de forma perfectamente simétrica:
            // 3 espacios iguales (arriba, centro, abajo)
            const double uniformGap = 12.0;
            final cardHeight =
                ((availableHeight - (3 * uniformGap)) / 2).clamp(180.0, 360.0);
            final rowExtent = cardHeight + uniformGap;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TvFixedWindowViewport(
                slotCount: _rowCount,
                slotExtent: rowExtent,
                alignment: Alignment.center,
                child: TvWindowedGrid<Movie>(
                  key: _listKey,
                  items: movies,
                  windowSize: _windowSize,
                  crossAxisCount: _crossAxisCount,
                  initialGlobalIndex: 0,
                  itemExtent: rowExtent,
                  crossAxisSpacing: 10,
                  showScrollDots: true,
                  onExitLeft: widget.onExitLeft,
                  itemBuilder: (
                    context,
                    movie,
                    focusNode,
                    localIndex,
                    globalIndex,
                    onKeyUp,
                    onKeyDown,
                    onKeyLeft,
                    onKeyRight,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: uniformGap / 2,
                      ),
                      child: TvMovieCard(
                        key: ValueKey(movie.id),
                        movie: movie,
                        focusNode: focusNode,
                        onKeyUp: onKeyUp,
                        onKeyDown: onKeyDown,
                        onKeyLeft: onKeyLeft,
                        onKeyRight: onKeyRight,
                        onTap: () => _openMovieDetail(movie),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
