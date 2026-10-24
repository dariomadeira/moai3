import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Área del rail para catálogos de Moiamov (Destacados, Películas, Series):
/// navegación vertical con grupos seccionales y grilla de 5 columnas para cada categoría.
class HomeMoviesArea extends StatefulWidget {
  final String section;
  final String panelTitle;
  final IconData? accordionIcon;
  final String emptyMessage;
  final VoidCallback onExitLeft;

  const HomeMoviesArea({
    super.key,
    this.section = FeaturedMoviesProvider.sectionFeatured,
    this.panelTitle = '',
    this.accordionIcon,
    this.emptyMessage = '',
    required this.onExitLeft,
  });

  static const icons = [
    MoaiIcons.tvAccordionFeatured,
  ];

  @override
  State<HomeMoviesArea> createState() => HomeMoviesAreaState();
}

class HomeMoviesAreaState extends HomeAreaState<HomeMoviesArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  static const int _crossAxisCount = 5;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');
  final Map<String, FocusNode> _focusNodes = {};
  final Map<int, GlobalKey> _categoryHeaderKeys = {};

  int _lastFocusedCat = 0;
  int _lastFocusedRow = 0;
  int _lastFocusedCol = 0;

  void focusGrid() {
    if (!mounted) return;
    final provider = context.read<FeaturedMoviesProvider>();
    final categories = provider.categoriesFor(widget.section);
    if (categories.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _focusCard(_lastFocusedCat, _lastFocusedRow, _lastFocusedCol);
  }

  @override
  void requestEntryFocus() => focusGrid();

  GlobalKey _getCategoryHeaderKey(int catIdx) {
    return _categoryHeaderKeys.putIfAbsent(catIdx, GlobalKey.new);
  }

  FocusNode _getNode(int catIdx, int r, int c) {
    final key = '${catIdx}_${r}_$c';
    return _focusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'movie_card_$key'),
    );
  }

  void _focusCard(int catIdx, int r, int c) {
    final key = '${catIdx}_${r}_$c';
    final node = _focusNodes[key];
    if (node != null && node.canRequestFocus) {
      _lastFocusedCat = catIdx;
      _lastFocusedRow = r;
      _lastFocusedCol = c;
      node.requestFocus();
    }
  }

  void _onCardFocused(int catIdx, int rowIdx, int colIdx) {
    _lastFocusedCat = catIdx;
    _lastFocusedRow = rowIdx;
    _lastFocusedCol = colIdx;

    if (catIdx == 0 && rowIdx == 0) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    if (rowIdx == 0) {
      final headerContext = _categoryHeaderKeys[catIdx]?.currentContext;
      if (headerContext != null) {
        Scrollable.ensureVisible(
          headerContext,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
        return;
      }
    }

    final cardNode = _focusNodes['${catIdx}_${rowIdx}_$colIdx'];
    final cardContext = cardNode?.context;
    if (cardContext != null) {
      Scrollable.ensureVisible(
        cardContext,
        alignment: 0.80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<MovieItem> _getChunk(List<MovieItem> movies, int rowIndex) {
    final start = rowIndex * _crossAxisCount;
    if (start >= movies.length) return [];
    final end = (start + _crossAxisCount).clamp(0, movies.length);
    return movies.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<FeaturedMoviesProvider>();
      if (!provider.loadedOnceFor(widget.section) ||
          (provider.itemsFor(widget.section).isEmpty &&
              !provider.isLoadingFor(widget.section))) {
        provider.loadSection(widget.section);
      }
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
    _categoryHeaderKeys.clear();
    _emptyFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onMovieTap(MovieItem movie) {
    if (!movie.isMovie) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieDetailScreen(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<FeaturedMoviesProvider>();
    final categories = provider.categoriesFor(widget.section);
    final isLoading = provider.isLoadingFor(widget.section);
    final loadedOnce = provider.loadedOnceFor(widget.section);
    final errorMessage = provider.errorMessageFor(widget.section);
    final errorDetail = provider.errorDetailFor(widget.section);

    final title = widget.panelTitle.isNotEmpty
        ? widget.panelTitle
        : LocaleKeys.movies_panel_featured_title.tr();
    final icon = widget.accordionIcon ?? MoaiIcons.tvAccordionFeatured;
    final emptyMsg = widget.emptyMessage.isNotEmpty
        ? widget.emptyMessage
        : LocaleKeys.movies_empty_featured.tr();

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface.withValues(alpha: 0.8)],
      titles: [title],
      icons: [icon],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        if ((!loadedOnce || isLoading) &&
            categories.isEmpty &&
            errorMessage == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (errorMessage != null && categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(MoaiIcons.error, size: 48, color: scheme.error),
                const SizedBox(height: 12),
                Text(
                  errorMessage.tr(namedArgs: {
                    'error': errorDetail ?? '',
                  }),
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context
                      .read<FeaturedMoviesProvider>()
                      .loadSection(widget.section, force: true),
                  child: Text(LocaleKeys.update_action_retry.tr()),
                ),
              ],
            ),
          );
        }

        if (categories.isEmpty) {
          return TvEmptyStateCard(
            focusNode: _emptyFocusNode,
            icon: MoaiIcons.tvMoviesEmpty,
            message: emptyMsg,
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            const double uniformGap = 12.0;
            const double horizontalPadding = 14.0;
            final netWidth = availableWidth -
                (horizontalPadding * 2) -
                ((_crossAxisCount - 1) * uniformGap);
            final colWidth = (netWidth / _crossAxisCount).clamp(100.0, 400.0);
            // Proporción estándar de afiche 262:370 (1:1.412) + barra inferior del título (30px)
            final cardHeight = (colWidth * (370 / 262)) + 30.0;

            return ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  right: 14,
                  top: 8,
                  bottom: 8,
                ),
                itemCount: categories.length,
                itemBuilder: (context, catIdx) {
                  final cat = categories[catIdx];
                  final totalRows =
                      (cat.movies.length + _crossAxisCount - 1) ~/
                      _crossAxisCount;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encabezado de la categoría con GlobalKey para scroll
                      _buildCategoryHeader(context, cat, catIdx, scheme),
                      // Filas de tarjetas (grilla de 5 columnas)
                      for (int r = 0; r < totalRows; r++) ...[
                        _buildMovieRow(
                          context,
                          categories,
                          catIdx,
                          r,
                          totalRows,
                          cardHeight,
                          uniformGap,
                        ),
                        if (r < totalRows - 1)
                          const SizedBox(height: uniformGap),
                      ],
                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    CategoryColumn cat,
    int catIdx,
    ColorScheme scheme,
  ) {
    return Container(
      key: _getCategoryHeaderKey(catIdx),
      padding: EdgeInsets.only(
        left: 4,
        top: catIdx == 0 ? 6 : 20,
        bottom: 12,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3.5,
            height: 20,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            cat.columnName,
            style: MoaiText.display(
              context,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${cat.movies.length}',
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieRow(
    BuildContext context,
    List<CategoryColumn> allCategories,
    int catIdx,
    int r,
    int totalRows,
    double cardHeight,
    double uniformGap,
  ) {
    final cat = allCategories[catIdx];
    final rowMovies = _getChunk(cat.movies, r);

    return SizedBox(
      height: cardHeight,
      child: Row(
        children: [
          for (int c = 0; c < _crossAxisCount; c++) ...[
            if (c < rowMovies.length) ...[
              Expanded(
                child: _MovieCardSlot(
                  movie: rowMovies[c],
                  focusNode: _getNode(catIdx, r, c),
                  catIdx: catIdx,
                  rowIdx: r,
                  colIdx: c,
                  onTap: () => _onMovieTap(rowMovies[c]),
                  onFocused: () => _onCardFocused(catIdx, r, c),
                  onKeyLeft: () {
                    if (c > 0) {
                      _focusCard(catIdx, r, c - 1);
                      return true;
                    }
                    widget.onExitLeft();
                    return true;
                  },
                  onKeyRight: () {
                    if (c < rowMovies.length - 1) {
                      _focusCard(catIdx, r, c + 1);
                      return true;
                    }
                    return true;
                  },
                  onKeyUp: () {
                    if (r > 0) {
                      final prevRowMovies = _getChunk(cat.movies, r - 1);
                      final targetCol = c.clamp(0, prevRowMovies.length - 1);
                      _focusCard(catIdx, r - 1, targetCol);
                    } else if (catIdx > 0) {
                      final prevCat = allCategories[catIdx - 1];
                      final prevTotalRows =
                          (prevCat.movies.length + _crossAxisCount - 1) ~/
                          _crossAxisCount;
                      final lastRow = prevTotalRows - 1;
                      final lastRowMovies =
                          _getChunk(prevCat.movies, lastRow);
                      final targetCol = c.clamp(0, lastRowMovies.length - 1);
                      _focusCard(catIdx - 1, lastRow, targetCol);
                    }
                  },
                  onKeyDown: () {
                    if (r < totalRows - 1) {
                      final nextRowMovies = _getChunk(cat.movies, r + 1);
                      final targetCol = c.clamp(0, nextRowMovies.length - 1);
                      _focusCard(catIdx, r + 1, targetCol);
                    } else if (catIdx < allCategories.length - 1) {
                      final nextCat = allCategories[catIdx + 1];
                      final firstRowMovies = _getChunk(nextCat.movies, 0);
                      final targetCol = c.clamp(0, firstRowMovies.length - 1);
                      _focusCard(catIdx + 1, 0, targetCol);
                    }
                  },
                ),
              ),
            ] else
              const Expanded(child: SizedBox.shrink()),
            if (c < _crossAxisCount - 1)
              SizedBox(width: uniformGap),
          ],
        ],
      ),
    );
  }
}

class _MovieCardSlot extends StatelessWidget {
  final MovieItem movie;
  final FocusNode focusNode;
  final int catIdx;
  final int rowIdx;
  final int colIdx;
  final VoidCallback onTap;
  final VoidCallback onFocused;
  final bool Function() onKeyLeft;
  final bool Function() onKeyRight;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  const _MovieCardSlot({
    required this.movie,
    required this.focusNode,
    required this.catIdx,
    required this.rowIdx,
    required this.colIdx,
    required this.onTap,
    required this.onFocused,
    required this.onKeyLeft,
    required this.onKeyRight,
    required this.onKeyUp,
    required this.onKeyDown,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: FocusNode(canRequestFocus: false),
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocused();
        }
      },
      child: TvMovieCard(
        key: ValueKey(
          movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}_${catIdx}_${rowIdx}_$colIdx',
        ),
        movie: movie,
        focusNode: focusNode,
        onTap: onTap,
        onKeyLeft: onKeyLeft,
        onKeyRight: onKeyRight,
        onKeyUp: onKeyUp,
        onKeyDown: onKeyDown,
      ),
    );
  }
}
