import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_fixed_window_viewport.dart';
import 'package:moai3/widgets/lists/tv_windowed_grid.dart';

/// Área del rail Películas: grilla plana de `masnew_featured` (browse-only).
class HomeMoviesArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  const HomeMoviesArea({
    super.key,
    required this.onExitLeft,
  });

  static const icons = [
    MoaiIcons.movieOutlined,
  ];

  @override
  State<HomeMoviesArea> createState() => HomeMoviesAreaState();
}

class HomeMoviesAreaState extends State<HomeMoviesArea> {
  static const int _crossAxisCount = 5;
  static const int _windowSize = 10;
  static const int _rowCount = _windowSize ~/ _crossAxisCount;

  final _listKey = GlobalKey<TvWindowedGridState<MovieItem>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');

  void focusGrid() {
    if (!mounted) return;
    final provider = context.read<FeaturedMoviesProvider>();
    if (provider.items.isEmpty) {
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
      if (!mounted) return;
      final provider = context.read<FeaturedMoviesProvider>();
      if (!provider.loadedOnce ||
          (provider.items.isEmpty && !provider.isLoading)) {
        provider.loadFeatured();
      }
    });
  }

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  /// Hook para detalle/play en una iteración posterior.
  void _onMovieTap(MovieItem movie) {
    // TODO: abrir detalle / reproducción.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<FeaturedMoviesProvider>();
    final movies = provider.items;

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface],
      titles: ['movies_panel_featured_title'.tr()],
      icons: HomeMoviesArea.icons,
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        if (provider.isLoading && movies.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null && movies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MoaiIcons.errorOutline, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context
                      .read<FeaturedMoviesProvider>()
                      .loadFeatured(force: true),
                  child: Text('update_action_retry'.tr()),
                ),
              ],
            ),
          );
        }

        if (movies.isEmpty) {
          return TvEmptyStateCard(
            focusNode: _emptyFocusNode,
            icon: MoaiIcons.hourglassEmpty,
            message: 'movies_empty_featured'.tr(),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            const double uniformGap = 12.0;
            final cardHeight =
                ((availableHeight - (3 * uniformGap)) / 2).clamp(180.0, 360.0);
            final rowExtent = cardHeight + uniformGap;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TvFixedWindowViewport(
                slotCount: _rowCount,
                slotExtent: rowExtent,
                alignment: Alignment.center,
                child: TvWindowedGrid<MovieItem>(
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
                        key: ValueKey(
                          movie.contentId.isNotEmpty
                              ? movie.contentId
                              : '${movie.name}_$globalIndex',
                        ),
                        movie: movie,
                        focusNode: focusNode,
                        onKeyUp: onKeyUp,
                        onKeyDown: onKeyDown,
                        onKeyLeft: onKeyLeft,
                        onKeyRight: onKeyRight,
                        onTap: () => _onMovieTap(movie),
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
