import 'dart:async';

import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
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
import 'package:moai3/services/home_hero_rotation.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

part 'movies/home_movies_navigation.dart';
part 'movies/home_movies_view.dart';

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
  double _columnWidth = 0;
  double _columnGap = _gap;

  final FocusNode _gridFocus = FocusNode(debugLabel: 'movies_grid');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'movies_empty');

  /// Banner de promoción, con su propio foco ([MovieHeroCard]) dentro del de
  /// la grilla.
  final FocusNode _bannerFocus = FocusNode(debugLabel: 'movies_banner');
  List<MovieItem> _banner = const [];

  /// Los pósters a la derecha del banner: las destacadas que siguen a las
  /// del banner (no se repiten), en las dos últimas columnas de la grilla.
  List<MovieItem> _side = const [];
  List<MovieItem> _best = const [];
  List<MovieItem> _bestSource = const [];

  /// Películas que rota el banner y pósters a su derecha.
  static const int _bannerCount = 6;
  static const int _sideCount = 2;

  /// Cada cuánto el banner pasa solo a la destacada siguiente.
  static const Duration _bannerEvery = Duration(seconds: 10);

  /// En la página de arriba (banner y "Lo mejor del año"). Se entra por ella.
  bool _onTop = true;

  /// En la página de arriba: el banner y no la fila.
  bool _onBanner = true;

  /// En la página de arriba: los pósters de al lado del banner (nunca junto
  /// con [_onBanner]).
  bool _onSide = false;
  int _sideCol = 0;
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

  /// Póster elegido al lado del banner (-1: ninguno).
  @visibleForTesting
  int get debugSideIndex => _onTop && _onSide ? _sideCol : -1;

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
    // El banner arranca con lo que eligió el Inicio: si la rotación no se
    // leyó todavía (se abrió la sección sin pasar por el Inicio), se lee.
    if (widget.promoBanner && !_rotation.isLoaded) {
      unawaited(
        _rotation.load().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
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
        ),
      ),
    );
  }

  /// La sección Series (el banner muestra series y abre su detalle).
  bool get _isSeries => widget.section == FeaturedMoviesProvider.sectionSeries;

  /// Con qué empieza el banner: lo que eligió la tarjeta del Inicio.
  HomeHeroRotation get _rotation =>
      _isSeries ? HomeHeroRotation.series : HomeHeroRotation.movies;

  /// Banner y "Lo mejor del año" (sin las del banner) para este catálogo.
  void _refreshTop(List<MovieItem> bestSource) {
    _bestSource = bestSource;
    if (!widget.promoBanner) {
      _banner = _side = _best = const [];
      return;
    }
    // Una sola lista de destacadas: las primeras rotan en el banner (las
    // mismas que elige el Inicio) y las que siguen van de póster al lado.
    const count = _bannerCount + _sideCount;
    final promo = _isSeries
        ? pickPromoSeries(_categories, count: count)
        : pickPromoMovies(_categories, count: count);
    _banner = List.unmodifiable(promo.take(_bannerCount));
    _side = List.unmodifiable(promo.skip(_bannerCount));
    final onTop = [..._banner, ..._side];
    if (_isSeries) {
      // TMDb no tiene series: la fila sale del catálogo, como el banner.
      _best = pickBestSeries(_categories, count: _bestCount, exclude: onTop);
      return;
    }
    final inBanner = {for (final m in onTop) normalizeText(m.name)};
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

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        // Ancho y alto finales del contenido expandido del acordeón (fijos,
        // sin importar en qué frame de la animación de 250 ms esté el panel).
        final targetWidth = TvAccordionRowPreview.contentWidth(
          totalWidth: outerConstraints.maxWidth,
          panelCount: panelCount,
        ).clamp(180.0, double.infinity);
        final targetHeight = outerConstraints.maxHeight;
        _layout(targetWidth, targetHeight);

        return TvAccordionRowPreview(
          panelCount: panelCount,
          activeIndex: _panel,
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

  /// Para las extensiones de los `part` (setState es protegido).
  void _update(VoidCallback fn) => setState(fn);
}
