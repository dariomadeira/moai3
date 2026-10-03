import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/models/torrent_stream.dart';
import 'package:moai3/state/movie_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_movie_detail_dialog.dart';

/// Área principal del catálogo de películas VOD envuelta en panel acordeón (SPEC-38).
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
  State<HomeMoviesArea> createState() => _HomeMoviesAreaState();
}

class _HomeMoviesAreaState extends State<HomeMoviesArea> {
  late FocusScopeNode _scopeNode;

  @override
  void initState() {
    super.initState();
    _scopeNode = FocusScopeNode(debugLabel: 'home_movies_scope');
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
    _scopeNode.dispose();
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
    final scheme = context.scheme;
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
        return FocusScope(
          node: _scopeNode,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Bar dentro del panel Disponibles
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.movie, color: scheme.primary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Películas & VOD',
                      style: MoaiText.display(
                        context,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (movies.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${movies.length} títulos',
                          style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar catálogo',
                      onPressed: () => context.read<MovieProvider>().loadPopularMovies(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Content Grid o indicador de carga
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : provider.errorMessage != null
                        ? Center(
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
                          )
                        : movies.isEmpty
                            ? const Center(
                                child: Text('No hay películas disponibles en el catálogo.'),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 0.62,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                ),
                                itemCount: movies.length,
                                itemBuilder: (context, index) {
                                  final movie = movies[index];
                                  return Focus(
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }

                                      // Izquierda desde la primera columna -> volver al NavigationRail
                                      if (event.logicalKey ==
                                              LogicalKeyboardKey.arrowLeft &&
                                          (index % 5) == 0) {
                                        widget.onExitLeft();
                                        return KeyEventResult.handled;
                                      }

                                      if (TvKeyHandler.isActionKey(event.logicalKey)) {
                                        _openMovieDetail(movie);
                                        return KeyEventResult.handled;
                                      }

                                      return KeyEventResult.ignored;
                                    },
                                    child: TvMovieCard(
                                      movie: movie,
                                      onTap: () => _openMovieDetail(movie),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
