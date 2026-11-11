import 'dart:async';

import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/home/widgets/home_watchlist_big_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/features/movies/movie_promo.dart';
import 'package:moai3/features/movies/widgets/movie_hero_card.dart';
import 'package:moai3/features/movies/widgets/movie_poster_grid.dart';
import 'package:moai3/features/movies/screens/movie_category_screen.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/screens/series_detail_screen.dart';
import 'package:moai3/features/movies/widgets/movie_search_panel.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Área del rail para catálogos de Moiamov (Destacados, Películas, Series):
/// grilla de 5 columnas por categoría. Con [searchEnabled] suma un segundo
/// panel "Buscar" (SPEC-45).
///
/// Sin scroll, como "Ver todas": se ve una categoría por vez (su título y dos
/// filas) y ↑/↓ la cambian, con los puntos de posición a la derecha. Con
/// [promoBanner], arriba de todo hay otra página: el banner y la fila "Lo
/// mejor del año"; ↓ desde esa fila pasa a las categorías.
///
/// La grilla tiene un único [FocusNode]: la película elegida es un índice
/// (categoría, fila, columna) y las tarjetas sólo la dibujan. Así el foco
/// nunca depende de que una fila esté armada. El banner tiene el suyo.
class HomeMoviesArea extends StatefulWidget {
  final String section;
  final String panelTitle;
  final IconData? accordionIcon;

  /// Ícono de la pestaña en SVG (gana a [accordionIcon]), para los que no
  /// están en `hugeicons_plus` (Series).
  final String? accordionSvgIcon;

  /// Color de la sección en el rail: el del contador de cada categoría.
  final Color sectionColor;
  final String emptyMessage;
  final bool searchEnabled;

  /// Página de arriba con el banner ([pickPromoMovies]) y "Lo mejor del año".
  final bool promoBanner;
  final VoidCallback onExitLeft;

  /// Búsqueda del servidor; en los tests se reemplaza.
  final MovieSearchFetcher? searchFetcher;

  const HomeMoviesArea({
    super.key,
    this.section = FeaturedMoviesProvider.sectionFeatured,
    this.panelTitle = '',
    this.accordionIcon,
    this.accordionSvgIcon,
    this.sectionColor = HomeWatchlistBigCard.color,
    this.emptyMessage = '',
    this.searchEnabled = false,
    this.promoBanner = false,
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

  /// Filas de una categoría a la vista.
  static const int _windowRows = 2;

  /// Quieto este tiempo en una categoría, se precargan las vecinas.
  static const Duration _precacheDelay = Duration(milliseconds: 300);
  Timer? _precacheTimer;

  /// Películas de "Lo mejor del año": una fila.
  static const int _bestCount = _crossAxisCount;

  static const double _gap = 12.0;
  static const double _horizontalPadding = 14.0;

  /// Entre la pestaña y la grilla, como el contenido del Inicio.
  static const double _leftPadding = 4.0;
  static const double _listPadding = 8.0;

  /// Título de "Lo mejor del año", debajo del banner: sólo el texto.
  static const double _bestHeaderHeight = 42.0;
  static const double _minHeaderHeight = 44.0;

  /// Geometría de la última construcción (ver build).
  double _headerHeight = 50.0;
  double _cardHeight = 0;
  double _columnGap = _gap;

  final FocusNode _gridFocus = FocusNode(debugLabel: 'movies_grid');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');

  /// Banner de promoción, con su propio foco ([MovieHeroCard]) dentro del de
  /// la grilla.
  final FocusNode _bannerFocus = FocusNode(debugLabel: 'movies_banner');
  List<MovieItem> _banner = const [];
  List<MovieItem> _best = const [];
  List<MovieItem> _bestSource = const [];

  /// En la página de arriba (banner y "Lo mejor del año"). Se entra por ella.
  bool _onTop = true;

  /// En la página de arriba: el banner y no la fila.
  bool _onBanner = true;
  int _bestCol = 0;

  int _cat = 0;
  int _row = 0;
  int _col = 0;

  /// Primera fila a la vista de la categoría elegida (más de dos filas).
  int _firstRow = 0;

  List<CategoryColumn> _categories = const [];

  /// Cada vista posible de las categorías: (categoría, primera fila). Un
  /// punto por cada una.
  List<(int, int)> _windows = const [];

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

  @visibleForTesting
  bool get debugOnTop => _onTop;

  @visibleForTesting
  bool get debugOnBanner => _onTop && _onBanner;

  @visibleForTesting
  int get debugBestIndex => _bestCol;

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
      return focused == _emptyFocusNode ||
          focused == _gridFocus ||
          focused == _bannerFocus;
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
    if (provider.categoriesFor(widget.section).isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _focus.node(_onTop && _onBanner ? _bannerFocus : _gridFocus);
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
  // Geometría y selección: todo se calcula, nada se busca en el árbol.
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

  int _maxFirstRow(int cat) {
    final max = _rowCount(_categories[cat]) - _windowRows;
    return max < 0 ? 0 : max;
  }

  void _recomputeWindows() {
    _windows = [
      for (var c = 0; c < _categories.length; c++)
        for (var f = 0; f <= _maxFirstRow(c); f++) (c, f),
    ];
  }

  /// Lleva la selección a un lugar válido si el catálogo cambió.
  void _clampSelection() {
    if (_banner.isEmpty) _onTop = false;
    if (_best.isEmpty) _onBanner = true;
    _bestCol = _bestCol.clamp(0, _best.isEmpty ? 0 : _best.length - 1);
    if (_categories.isEmpty) {
      _cat = _row = _col = _firstRow = 0;
      return;
    }
    _cat = _cat.clamp(0, _categories.length - 1);
    _row = _row.clamp(0, _rowCount(_categories[_cat]) - 1);
    _col = _col.clamp(0, _rowLength(_cat, _row) - 1);
    _placeWindow();
  }

  /// Corre la vista lo justo para que la fila elegida quede adentro.
  void _placeWindow() {
    if (_row < _firstRow) {
      _firstRow = _row;
    } else if (_row > _firstRow + _windowRows - 1) {
      _firstRow = _row - _windowRows + 1;
    }
    _firstRow = _firstRow.clamp(0, _maxFirstRow(_cat));
  }

  /// Precarga las categorías vecinas al quedarse quieto: con la flecha
  /// mantenida no se acumulan decodificaciones de categorías que ya pasaron.
  void _schedulePrecache() {
    _precacheTimer?.cancel();
    _precacheTimer = Timer(_precacheDelay, _precacheNeighbors);
  }

  /// Los pósters de las categorías a un ↑/↓ de distancia: aparecen al
  /// instante, sin el fundido de carga.
  void _precacheNeighbors() {
    if (!mounted || _categories.isEmpty) return;
    for (final index in _onTop ? [0] : [_cat - 1, _cat + 1]) {
      if (index < 0 || index >= _categories.length) continue;
      for (final movie in _categories[index].movies) {
        final poster = movie.poster;
        if (poster == null || poster.isEmpty) continue;
        precacheImage(
          TvMovieCard.posterImage(poster),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  void _select(int cat, int row, int col) {
    if (cat != _cat || _onTop) _schedulePrecache();
    setState(() {
      _onTop = false;
      // Otra categoría: desde arriba entra por su principio y desde abajo,
      // por su final.
      if (cat != _cat) _firstRow = row == 0 ? 0 : row;
      _cat = cat;
      _row = row;
      _col = col;
      _placeWindow();
    });
  }

  /// A la página de arriba: al banner o a la fila (si hay), en la columna
  /// [col] si viene de las categorías.
  void _goTop({required bool banner, int? col}) {
    _schedulePrecache();
    setState(() {
      _onTop = true;
      _onBanner = banner || _best.isEmpty;
      if (col != null) {
        _bestCol = col.clamp(0, _best.isEmpty ? 0 : _best.length - 1);
      }
    });
    _focus.node(_onBanner ? _bannerFocus : _gridFocus);
  }

  /// ↓ desde el banner: a la fila de abajo o, si no hay, a las categorías.
  void _leaveBanner() {
    if (_best.isEmpty) {
      _goToCategories(_col);
      return;
    }
    setState(() => _onBanner = false);
    _gridFocus.requestFocus();
  }

  /// A la primera fila de la primera categoría, en la columna [col].
  void _goToCategories(int col) {
    _gridFocus.requestFocus();
    _select(0, 0, col.clamp(0, _rowLength(0, 0) - 1));
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
    } else if (_banner.isNotEmpty) {
      _goTop(banner: false, col: _col);
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
    // Lo que el banner no usa sube hasta acá: no mueve la grilla.
    if (_categories.isEmpty || (_onTop && _onBanner)) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (_onTop) return _onBestKey(key, repeat);

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

  /// La fila "Lo mejor del año": ↑ al banner, ↓ a las categorías.
  KeyEventResult _onBestKey(LogicalKeyboardKey key, bool repeat) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_bestCol > 0) {
        setState(() => _bestCol--);
      } else {
        widget.onExitLeft();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (_bestCol < _best.length - 1) {
        setState(() => _bestCol++);
      } else {
        _openSearch();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!repeat) _goTop(banner: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _goToCategories(_bestCol);
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      _onMovieTap(_best[_bestCol]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Ciclo de vida.
  // ---------------------------------------------------------------------------

  void _onGridFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _gridFocus.addListener(_onGridFocusChange);
    if (widget.searchEnabled) {
      _search = MovieSearchController(
        series: widget.section == FeaturedMoviesProvider.sectionSeries,
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
    _precacheTimer?.cancel();
    _gridFocus.removeListener(_onGridFocusChange);
    _gridFocus.dispose();
    _emptyFocusNode.dispose();
    _bannerFocus.dispose();
    _search?.dispose();
    _searchFieldFocus.dispose();
    _searchClearFocus.dispose();
    super.dispose();
  }

  void _onMovieTap(MovieItem movie) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => movie.isSeries
            ? SeriesDetailScreen(series: movie)
            : MovieDetailScreen(movie: movie),
      ),
    );
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
          series: widget.section == FeaturedMoviesProvider.sectionSeries,
          sectionColor: widget.sectionColor,
        ),
      ),
    );
  }

  /// Banner y "Lo mejor del año" (sin las del banner) para este catálogo.
  void _refreshTop(List<MovieItem> bestSource) {
    _bestSource = bestSource;
    if (!widget.promoBanner) {
      _banner = _best = const [];
      return;
    }
    _banner = pickPromoMovies(_categories);
    final inBanner = {for (final m in _banner) normalizeText(m.name)};
    _best = List.unmodifiable(
      bestSource
          .where((m) => !inBanner.contains(normalizeText(m.name)))
          .take(_bestCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sólo lo de esta sección: si otra carga (p. ej. el Inicio pide Películas
    // para los adelantos), la grilla no se reconstruye.
    final (
      categories,
      bestOfYear,
      isLoading,
      loadedOnce,
      errorMessage,
      errorDetail,
    ) = context.select(
      (FeaturedMoviesProvider p) => (
        p.categoriesFor(widget.section),
        p.bestOfYearFor(widget.section),
        p.isLoadingFor(widget.section),
        p.loadedOnceFor(widget.section),
        p.errorMessageFor(widget.section),
        p.errorDetailFor(widget.section),
      ),
    );

    if (!identical(categories, _categories) ||
        !identical(bestOfYear, _bestSource)) {
      _categories = categories;
      _refreshTop(bestOfYear);
      _recomputeWindows();
      _clampSelection();
      _schedulePrecache();
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
        _layout(targetWidth, targetHeight);

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
          svgIcons: [widget.accordionSvgIcon, if (search != null) null],
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

            return _buildGrid(context, scheme, targetHeight);
          },
        );
      },
    );
  }

  /// Tamaño de las tarjetas: como en Películas de siempre, con el lugar de
  /// los puntos; si título y dos filas no entran de alto, se achican y lo
  /// que sobra de ancho va entre las columnas (como [MoviePosterGrid]).
  void _layout(double width, double height) {
    final net =
        width - _leftPadding - _horizontalPadding - MoviePositionDots.width;
    var colWidth = ((net - (_crossAxisCount - 1) * _gap) / _crossAxisCount)
        .clamp(100.0, 400.0);
    var cardHeight = TvMovieCard.heightForWidth(colWidth);
    final room =
        height -
        _listPadding -
        _minHeaderHeight -
        (_windowRows - 1) * _gap -
        _horizontalPadding;
    if (room > 0 && cardHeight * _windowRows > room) {
      cardHeight = room / _windowRows;
      colWidth = TvMovieCard.widthForHeight(cardHeight);
    }
    _cardHeight = cardHeight;
    _columnGap = (net - _crossAxisCount * colWidth) / (_crossAxisCount - 1);
    // Lo que sobra de alto con dos filas va al encabezado: el hueco de
    // abajo queda igual al de la derecha.
    _headerHeight =
        (height -
                _listPadding -
                _windowRows * _cardHeight -
                (_windowRows - 1) * _gap -
                _horizontalPadding)
            .clamp(_minHeaderHeight, 72.0);
  }

  Widget _buildGrid(BuildContext context, ColorScheme scheme, double height) {
    // Con el foco en el banner (adentro de la grilla) no hay tarjeta elegida.
    final gridFocused = _gridFocus.hasPrimaryFocus;
    final rowsHeight = _windowRows * _cardHeight + (_windowRows - 1) * _gap;
    final rowsTop = _listPadding + _headerHeight;
    final bottom = height - rowsTop - rowsHeight;
    final hasTop = _banner.isNotEmpty;
    final windowIndex = _windows.indexOf((_cat, _firstRow));
    final page = _onTop
        ? _buildTopPage(context, scheme, gridFocused, bottom)
        : _buildCategoryPage(context, scheme, gridFocused);

    return Focus(
      focusNode: _gridFocus,
      onKeyEvent: _onGridKey,
      child: Padding(
        padding: const EdgeInsets.only(
          left: _leftPadding,
          right: _horizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: height,
                // Entre páginas, un fundido corto; entre categorías, nada.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(key: ValueKey(_onTop), child: page),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: rowsTop),
              child: SizedBox(
                width: MoviePositionDots.width,
                height: rowsHeight,
                child: MoviePositionDots(
                  count: (hasTop ? 1 : 0) + _windows.length,
                  current: _onTop
                      ? 0
                      : (hasTop ? 1 : 0) + (windowIndex < 0 ? 0 : windowIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El banner y, debajo, "Lo mejor del año" a la altura de la segunda fila
  /// de las categorías.
  Widget _buildTopPage(
    BuildContext context,
    ColorScheme scheme,
    bool gridFocused,
    double bottom,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Arriba, el mismo margen que a los costados.
        const SizedBox(height: _horizontalPadding),
        Expanded(child: _buildBanner()),
        if (_best.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: _bestHeaderHeight,
            child: _buildHeader(
              context,
              scheme,
              LocaleKeys.movies_best_of_year.tr(
                namedArgs: {'year': '${DateTime.now().year}'},
              ),
            ),
          ),
          SizedBox(
            height: _cardHeight,
            child: _buildBestRow(gridFocused && !_onBanner ? _bestCol : -1),
          ),
        ],
        SizedBox(height: bottom),
      ],
    );
  }

  /// El título de la categoría elegida y sus dos filas a la vista.
  Widget _buildCategoryPage(
    BuildContext context,
    ColorScheme scheme,
    bool gridFocused,
  ) {
    final cat = _categories[_cat];
    final rows = _rowCount(cat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _listPadding),
        SizedBox(
          height: _headerHeight,
          child: _buildHeader(
            context,
            scheme,
            cat.columnName,
            // Con "Ver todas" la cantidad mostrada no dice cuántas hay.
            count: cat.hasMore ? null : cat.movies.length,
          ),
        ),
        for (var r = _firstRow; r < _firstRow + _windowRows; r++) ...[
          if (r > _firstRow) const SizedBox(height: _gap),
          SizedBox(
            height: _cardHeight,
            child: r < rows
                ? _buildMovieRow(
                    cat,
                    _cat,
                    r,
                    gridFocused && r == _row ? _col : -1,
                  )
                : null,
          ),
        ],
      ],
    );
  }

  /// La tarjeta destacada del Inicio a todo el ancho, con la foto a la
  /// derecha. ← sale al rail, → desde la última flecha va a Buscar, ↓ baja a
  /// la fila; arriba no hay nada.
  Widget _buildBanner() {
    final watchlist = MovieWatchlistService.instance;
    return ListenableBuilder(
      listenable: watchlist,
      builder: (context, _) => MovieHeroCard(
        movies: _banner,
        focusNode: _bannerFocus,
        wideImage: true,
        tintFromImage: true,
        elevated: false,
        onPlay: (movie) => playMovie(context, movie),
        onOpen: _onMovieTap,
        onToggleInteresting: watchlist.toggle,
        isInteresting: (movie) => watchlist.contains(movie.contentId),
        onExitLeft: widget.onExitLeft,
        onExitRight: _openSearch,
        onExitUp: () {},
        onExitDown: _leaveBanner,
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    String title, {
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Como los títulos de los paneles: sin la barrita del acento y
            // con el degradado.
            Flexible(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: HomeClock.timeShader,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    fontSize: 18,
                    headline: true,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 10),
              // Sólido, del color de la sección en el rail (Películas naranja,
              // Series cian).
              TvMetaPill(
                label: '$count',
                tint: widget.sectionColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBestRow(int selectedCol) {
    return Row(
      children: [
        for (int c = 0; c < _crossAxisCount; c++) ...[
          Expanded(
            child: c < _best.length
                ? _buildTile(_best[c], 'best_$c', c == selectedCol, () {
                    setState(() {
                      _onTop = true;
                      _onBanner = false;
                      _bestCol = c;
                    });
                    _gridFocus.requestFocus();
                    _onMovieTap(_best[c]);
                  })
                : const SizedBox.shrink(),
          ),
          if (c < _crossAxisCount - 1) SizedBox(width: _columnGap),
        ],
      ],
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
                    '${catIdx}_${row}_$c',
                    selectedCol == c,
                    () {
                      _gridFocus.requestFocus();
                      _select(catIdx, row, c);
                      _onMovieTap(cat.movies[start + c]);
                    },
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
          if (c < _crossAxisCount - 1) SizedBox(width: _columnGap),
        ],
      ],
    );
  }

  Widget _buildTile(
    MovieItem movie,
    String fallbackKey,
    bool selected,
    VoidCallback onTap,
  ) {
    // Cada tarjeta repinta sola: mover la selección toca sólo dos.
    return RepaintBoundary(
      child: TvMovieCard(
        key: ValueKey(
          movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}_$fallbackKey',
        ),
        movie: movie,
        isSelected: selected,
        onTap: onTap,
      ),
    );
  }
}
