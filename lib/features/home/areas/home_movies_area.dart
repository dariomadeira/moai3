import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
import 'package:moai3/features/movies/screens/movie_category_screen.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/widgets/movie_search_panel.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Área del rail para catálogos de Moiamov (Destacados, Películas, Series):
/// navegación vertical con grupos seccionales y grilla de 5 columnas para cada categoría.
/// Con [searchEnabled] suma un segundo panel "Buscar" (SPEC-45).
///
/// La grilla tiene un único [FocusNode]: la película elegida es un índice
/// (categoría, fila, columna) y las tarjetas sólo la dibujan. Así el foco
/// nunca depende de que una fila esté armada, y como todas las filas y
/// encabezados miden lo mismo, el scroll a cualquier película se calcula.
class HomeMoviesArea extends StatefulWidget {
  final String section;
  final String panelTitle;
  final IconData? accordionIcon;
  final String emptyMessage;
  final bool searchEnabled;
  final VoidCallback onExitLeft;

  /// Búsqueda del servidor; en los tests se reemplaza.
  final MovieSearchFetcher? searchFetcher;

  const HomeMoviesArea({
    super.key,
    this.section = FeaturedMoviesProvider.sectionFeatured,
    this.panelTitle = '',
    this.accordionIcon,
    this.emptyMessage = '',
    this.searchEnabled = false,
    this.searchFetcher,
    required this.onExitLeft,
  });

  static const icons = [MoaiIcons.tvAccordionFeatured];

  @override
  State<HomeMoviesArea> createState() => HomeMoviesAreaState();
}

class HomeMoviesAreaState extends HomeAreaState<HomeMoviesArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  static const int _crossAxisCount = 5;

  /// Alto fijo de cada encabezado de categoría.
  static const double _headerHeight = 50.0;
  static const double _gap = 12.0;
  static const double _horizontalPadding = 14.0;
  static const double _listPadding = 8.0;

  ScrollController _scrollController = ScrollController();

  /// Posición del scroll, para volver al mismo lugar si la grilla se vuelve
  /// a armar (p. ej. al regresar de Buscar).
  double _savedOffset = 0;

  final FocusNode _gridFocus = FocusNode(debugLabel: 'movies_grid');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');

  int _cat = 0;
  int _row = 0;
  int _col = 0;

  /// Datos de la última construcción, para calcular posiciones.
  List<CategoryColumn> _categories = const [];
  double _cardHeight = 0;

  /// Índice del encabezado de cada categoría en la lista.
  List<int> _headerIndex = const [];
  Set<int> _headerSet = const {};

  /// 0: la grilla; 1: Buscar.
  int _panel = 0;
  MovieSearchController? _search;
  final FocusNode _searchFieldFocus = FocusNode(debugLabel: 'movie_search');
  final FocusNode _searchClearFocus = FocusNode(
    debugLabel: 'movie_search_clear',
  );

  /// Película elegida (categoría, fila, columna); para los tests.
  @visibleForTesting
  (int, int, int) get debugSelection => (_cat, _row, _col);

  void _openSearch() {
    if (!widget.searchEnabled) return;
    setState(() => _panel = 1);
    _focus.node(_searchFieldFocus);
  }

  void _closeSearch() {
    if (_panel == 0) return;
    setState(() => _panel = 0);
    // La grilla se vuelve a armar en el próximo frame.
    _focus.request(() {
      focusGrid();
      final focused = FocusManager.instance.primaryFocus;
      return focused == _emptyFocusNode || focused == _gridFocus;
    });
  }

  void _openSearchResult(MovieItem movie) {
    _search?.rememberQuery();
    _onMovieTap(movie);
  }

  @override
  bool handleBack() {
    if (_panel == 0) return false;
    _closeSearch();
    return true;
  }

  void focusGrid() {
    if (!mounted) return;
    final provider = context.read<FeaturedMoviesProvider>();
    final categories = provider.categoriesFor(widget.section);
    if (categories.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    if (_gridFocus.context == null) return;
    _gridFocus.requestFocus();
    // Sin animación: al volver, la película elegida ya está en su lugar.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(animate: false),
    );
  }

  /// Desde el rail siempre a la grilla (SPEC-45 §2.1).
  @override
  void requestEntryFocus() {
    if (_panel == 1) {
      _closeSearch();
    } else {
      focusGrid();
    }
  }

  // ---------------------------------------------------------------------------
  // Geometría: todo se calcula, nada se busca en el árbol.
  // ---------------------------------------------------------------------------

  /// Casilleros de la categoría: sus películas y, si la lleva, "Ver todas".
  static int _slotCount(CategoryColumn cat) =>
      cat.movies.length + (cat.hasMore ? 1 : 0);

  /// Filas de la grilla de 5 columnas que ocupa la categoría.
  int _rowCount(CategoryColumn cat) =>
      (_slotCount(cat) + _crossAxisCount - 1) ~/ _crossAxisCount;

  /// Casilleros de la fila [row] de la categoría [cat].
  int _rowLength(int cat, int row) {
    final total = _slotCount(_categories[cat]);
    final start = row * _crossAxisCount;
    return (total - start).clamp(0, _crossAxisCount);
  }

  double get _rowExtent => _cardHeight + _gap;

  /// Inicio (en píxeles, sin el relleno de la lista) del encabezado de [cat].
  double _headerOffset(int cat) {
    var offset = 0.0;
    for (var c = 0; c < cat; c++) {
      offset += _headerHeight + _rowCount(_categories[c]) * _rowExtent;
    }
    return offset;
  }

  double get _totalExtent => _headerOffset(_categories.length);

  void _recomputeIndex() {
    final index = <int>[];
    var i = 0;
    for (final cat in _categories) {
      index.add(i);
      i += 1 + _rowCount(cat);
    }
    _headerIndex = index;
    _headerSet = index.toSet();
  }

  /// Lleva la selección a un lugar válido si el catálogo cambió.
  void _clampSelection() {
    if (_categories.isEmpty) {
      _cat = _row = _col = 0;
      return;
    }
    _cat = _cat.clamp(0, _categories.length - 1);
    _row = _row.clamp(0, _rowCount(_categories[_cat]) - 1);
    _col = _col.clamp(0, _rowLength(_cat, _row) - 1);
  }

  /// Calcula el offset que deja completamente visible la fila seleccionada.
  double _targetOffsetFor(double currentOffset, double viewport) {
    if (_categories.isEmpty || viewport <= 0 || _cardHeight <= 0) {
      return currentOffset;
    }
    final rowTop =
        _listPadding + _headerOffset(_cat) + _headerHeight + _row * _rowExtent;
    final top = _row == 0 ? rowTop - _headerHeight : rowTop;
    final bottom = rowTop + _cardHeight + _gap + _listPadding;

    var target = currentOffset;
    if (_cat == 0 && _row == 0) {
      target = 0.0;
    } else if (top < target) {
      target = top;
    } else if (bottom > target + viewport) {
      target = bottom - viewport;
    }
    final maxOffset = (_totalExtent + _listPadding * 2 - viewport).clamp(
      0.0,
      double.infinity,
    );
    return target.clamp(0.0, maxOffset);
  }

  /// Desplaza la lista lo justo para que se vea la película elegida (y el
  /// encabezado, si es la primera fila de la categoría).
  void _reveal({bool animate = true}) {
    if (!mounted || !_scrollController.hasClients || _categories.isEmpty) {
      return;
    }
    final position = _scrollController.position;
    final viewport = position.viewportDimension;
    final current = position.pixels;
    final target = _targetOffsetFor(current, viewport);
    _savedOffset = target;
    if ((target - current).abs() < 0.5) return;

    // Saltos largos (p. ej. al volver de Buscar) van directo.
    if (!animate || (target - current).abs() > viewport * 1.5) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _select(int cat, int row, int col) {
    setState(() {
      _cat = cat;
      _row = row;
      _col = col;
    });
    _reveal();
  }

  // ---------------------------------------------------------------------------
  // Teclas.
  // ---------------------------------------------------------------------------

  void _moveUp() {
    if (_row > 0) {
      _select(_cat, _row - 1, _col.clamp(0, _rowLength(_cat, _row - 1) - 1));
    } else if (_cat > 0) {
      final prev = _cat - 1;
      final lastRow = _rowCount(_categories[prev]) - 1;
      _select(prev, lastRow, _col.clamp(0, _rowLength(prev, lastRow) - 1));
    }
  }

  void _moveDown() {
    if (_row < _rowCount(_categories[_cat]) - 1) {
      _select(_cat, _row + 1, _col.clamp(0, _rowLength(_cat, _row + 1) - 1));
    } else if (_cat < _categories.length - 1) {
      final next = _cat + 1;
      _select(next, 0, _col.clamp(0, _rowLength(next, 0) - 1));
    }
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    if (_categories.isEmpty) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_col > 0) {
        _select(_cat, _row, _col - 1);
      } else {
        widget.onExitLeft();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (_col < _rowLength(_cat, _row) - 1) {
        _select(_cat, _row, _col + 1);
      } else {
        // Última película de la fila: al panel Buscar.
        _openSearch();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveDown();
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      final index = _row * _crossAxisCount + _col;
      final category = _categories[_cat];
      if (index < category.movies.length) {
        _onMovieTap(category.movies[index]);
      } else if (category.hasMore) {
        _openCategory(category);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida.
  // ---------------------------------------------------------------------------

  void _trackOffset() {
    if (_scrollController.hasClients) {
      _savedOffset = _scrollController.offset;
    }
  }

  void _onGridFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_trackOffset);
    _gridFocus.addListener(_onGridFocusChange);
    if (widget.searchEnabled) {
      _search = MovieSearchController(
        fetch:
            widget.searchFetcher ??
            (query, page) =>
                MoiamovApiService.instance.searchMovies(query, page: page),
        localMovies: () =>
            context.read<FeaturedMoviesProvider>().itemsFor(widget.section),
      )..loadHistory();
    }
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
    _gridFocus.removeListener(_onGridFocusChange);
    _gridFocus.dispose();
    _emptyFocusNode.dispose();
    _scrollController.removeListener(_trackOffset);
    _scrollController.dispose();
    _search?.dispose();
    _searchFieldFocus.dispose();
    _searchClearFocus.dispose();
    super.dispose();
  }

  /// Si la lista se desarmó (otro panel abierto), la próxima arranca donde
  /// estaba la anterior y garantiza que la película elegida quede a la vista.
  ScrollController _controllerForGrid(double viewport) {
    if (!_scrollController.hasClients) {
      _savedOffset = _targetOffsetFor(_savedOffset, viewport);
      if (_scrollController.initialScrollOffset != _savedOffset) {
        final old = _scrollController..removeListener(_trackOffset);
        _scrollController = ScrollController(initialScrollOffset: _savedOffset)
          ..addListener(_trackOffset);
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    }
    return _scrollController;
  }

  void _onMovieTap(MovieItem movie) {
    // Películas y tráileres tienen detalle; las series todavía no.
    if (movie.isSeries) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
  }

  /// "Ver todas": la categoría completa del servidor (SPEC-44 §3.3). Al
  /// volver, la grilla sigue en la misma tarjeta.
  void _openCategory(CategoryColumn category) {
    final provider = context.read<FeaturedMoviesProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieCategoryScreen(
          category: category,
          initial: provider.shelfSnapshot(category.columnId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sólo lo de esta sección: si otra carga (p. ej. el Inicio pide Películas
    // para los adelantos), la grilla no se reconstruye.
    final (
      categories,
      isLoading,
      loadedOnce,
      errorMessage,
      errorDetail,
    ) = context.select(
      (FeaturedMoviesProvider p) => (
        p.categoriesFor(widget.section),
        p.isLoadingFor(widget.section),
        p.loadedOnceFor(widget.section),
        p.errorMessageFor(widget.section),
        p.errorDetailFor(widget.section),
      ),
    );

    if (!identical(categories, _categories)) {
      _categories = categories;
      _recomputeIndex();
      _clampSelection();
    }

    final title = widget.panelTitle.isNotEmpty
        ? widget.panelTitle
        : LocaleKeys.movies_panel_featured_title.tr();
    final icon = widget.accordionIcon ?? MoaiIcons.tvAccordionFeatured;
    final emptyMsg = widget.emptyMessage.isNotEmpty
        ? widget.emptyMessage
        : LocaleKeys.movies_empty_featured.tr();

    final search = _search;
    final panelCount = search == null ? 1 : 2;
    final glass = MoaiGlassScope.enabledOf(context);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // Ancho y alto finales del contenido expandido del acordeón (fijos,
        // sin importar en qué frame de la animación de 250 ms esté el panel).
        final targetWidth = TvAccordionRowPreview.contentWidth(
          totalWidth: outerConstraints.maxWidth,
          panelCount: panelCount,
          glass: glass,
        ).clamp(180.0, double.infinity);
        final targetHeight = outerConstraints.maxHeight - (glass ? 0.0 : 2.0);

        final netWidth =
            targetWidth -
            (_horizontalPadding * 2) -
            ((_crossAxisCount - 1) * _gap);
        final colWidth = (netWidth / _crossAxisCount).clamp(100.0, 400.0);
        // Proporción estándar de afiche 262:370 (1:1.412) + barra inferior del título (30px)
        _cardHeight = (colWidth * (370 / 262)) + 30.0;

        return TvAccordionRowPreview(
          panelCount: panelCount,
          activeIndex: _panel,
          colors: [
            scheme.surface.withValues(alpha: 0.8),
            if (search != null) scheme.surface.withValues(alpha: 0.8),
          ],
          titles: [
            title,
            if (search != null) LocaleKeys.movies_panel_search_title.tr(),
          ],
          icons: [icon, if (search != null) MoaiIcons.moviesSearch],
          onPanelTap: (index) => index == 1 ? _openSearch() : _closeSearch(),
          fixedContentWidth: true,
          buildExpandedContent: (index, title) {
            if (index == 1 && search != null) {
              return MovieSearchPanel(
                controller: search,
                fieldFocusNode: _searchFieldFocus,
                clearFocusNode: _searchClearFocus,
                onExitLeft: _closeSearch,
                onOpenMovie: _openSearchResult,
              );
            }
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
                    Icon(
                      MoaiIcons.error,
                      size: MoaiIconSizes.hero,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage.tr(namedArgs: {'error': errorDetail ?? ''}),
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

            final itemCount = _headerIndex.isEmpty
                ? 0
                : _headerIndex.last + 1 + _rowCount(categories.last);
            final gridFocused = _gridFocus.hasFocus;

            // La grilla mantiene siempre su ancho final (`fixedContentWidth`):
            // mientras el acordeón se abre o cierra, la descubre como una
            // cortina sin redimensionar pósters ni recalcular alturas.
            return Focus(
              focusNode: _gridFocus,
              onKeyEvent: _onGridKey,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(scrollbars: false),
                child: ListView.builder(
                  controller: _controllerForGrid(targetHeight),
                  padding: const EdgeInsets.only(
                    right: _horizontalPadding,
                    top: _listPadding,
                    bottom: _listPadding,
                  ),
                  scrollCacheExtent: ScrollCacheExtent.pixels(_cardHeight),
                  // Alturas fijas: Flutter no mide nada y el scroll es exacto.
                  itemExtentBuilder: (index, _) =>
                      _headerSet.contains(index) ? _headerHeight : _rowExtent,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    final (catIdx, row) = _locate(index);
                    if (row < 0) {
                      return _buildCategoryHeader(
                        context,
                        categories[catIdx],
                        scheme,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: _buildMovieRow(
                        categories[catIdx],
                        catIdx,
                        row,
                        gridFocused && catIdx == _cat && row == _row
                            ? _col
                            : -1,
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

  /// Categoría y fila del ítem [index] de la lista; fila -1 es el encabezado.
  (int, int) _locate(int index) {
    var cat = 0;
    for (var c = _headerIndex.length - 1; c >= 0; c--) {
      if (_headerIndex[c] <= index) {
        cat = c;
        break;
      }
    }
    return (cat, index - _headerIndex[cat] - 1);
  }

  Widget _buildCategoryHeader(
    BuildContext context,
    CategoryColumn cat,
    ColorScheme scheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.bottomLeft,
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
            Flexible(
              child: Text(
                cat.columnName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  fontSize: 18,
                  color: scheme.onSurface,
                ),
              ),
            ),
            // Con "Ver todas" la cantidad mostrada no dice cuántas hay.
            if (!cat.hasMore) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: MoaiGlassScope.enabledOf(context)
                    ? moaiGlassChipDecoration(scheme, radius: 10)
                    : BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                child: Text(
                  '${cat.movies.length}',
                  style: MoaiText.body(
                    context,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MoaiGlassScope.enabledOf(context)
                        ? scheme.onSurface
                        : scheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Una fila de 5 tarjetas; [selectedCol] es la elegida (-1: ninguna).
  Widget _buildMovieRow(
    CategoryColumn cat,
    int catIdx,
    int row,
    int selectedCol,
  ) {
    final start = row * _crossAxisCount;
    return Row(
      children: [
        for (int c = 0; c < _crossAxisCount; c++) ...[
          Expanded(
            child: start + c < cat.movies.length
                ? _buildTile(
                    cat.movies[start + c],
                    catIdx,
                    row,
                    c,
                    selectedCol == c,
                  )
                : start + c == cat.movies.length && cat.hasMore
                ? RepaintBoundary(
                    child: TvShowAllCard(
                      categoryName: cat.columnName,
                      isSelected: selectedCol == c,
                      onTap: () {
                        _gridFocus.requestFocus();
                        _select(catIdx, row, c);
                        _openCategory(cat);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (c < _crossAxisCount - 1) const SizedBox(width: _gap),
        ],
      ],
    );
  }

  Widget _buildTile(
    MovieItem movie,
    int catIdx,
    int row,
    int col,
    bool selected,
  ) {
    // Cada tarjeta repinta sola: mover la selección toca sólo dos.
    return RepaintBoundary(
      child: TvMovieCard(
        key: ValueKey(
          movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}_${catIdx}_${row}_$col',
        ),
        movie: movie,
        isSelected: selected,
        onTap: () {
          _gridFocus.requestFocus();
          _select(catIdx, row, col);
          _onMovieTap(movie);
        },
      ),
    );
  }
}
