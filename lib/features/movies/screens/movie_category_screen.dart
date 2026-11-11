import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/home/widgets/home_watchlist_big_card.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/screens/series_detail_screen.dart';
import 'package:moai3/features/movies/widgets/movie_poster_grid.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_grid_catalog.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:provider/provider.dart';

/// Una página de la categoría (`getShelveData`); `null` si falla.
typedef CategoryPageFetcher = Future<List<MovieItem>?> Function(int page);

/// "Ver todas": una categoría completa del servidor (SPEC-44 §3.3), en la
/// misma grilla de 5 columnas que Películas ([MoviePosterGrid]) y cargando de
/// a una página ([FeaturedMoviesProvider.shelfPageSize]) al acercarse al
/// final. Las páginas nuevas se suman abajo: el foco nunca se mueve solo.
class MovieCategoryScreen extends StatefulWidget {
  const MovieCategoryScreen({
    super.key,
    required this.category,
    this.initial,
    this.fetchPage,
    this.fetchTotal,
    this.series = false,
    this.sectionColor = HomeWatchlistBigCard.color,
  });

  final CategoryColumn category;

  /// Categoría de Series: de la lista del servidor se queda con las series
  /// (y la pestaña lleva el ícono de Series).
  final bool series;

  /// Color de la sección en el rail: el del contador.
  final Color sectionColor;

  /// Lo que ya bajó la grilla de esta categoría
  /// ([FeaturedMoviesProvider.shelfSnapshot]): se muestra al instante y se
  /// sigue desde la página siguiente.
  final ({List<MovieItem> movies, int pages, bool ended})? initial;

  /// Por defecto [MoiamovApiService.fetchShelf]; los tests lo reemplazan.
  final CategoryPageFetcher? fetchPage;

  /// Cuántas tiene la categoría; por defecto
  /// [MoiamovApiService.fetchShelfTotal]. Los tests lo reemplazan.
  final Future<int?> Function()? fetchTotal;

  @override
  State<MovieCategoryScreen> createState() => MovieCategoryScreenState();
}

@visibleForTesting
class MovieCategoryScreenState extends State<MovieCategoryScreen> {
  final _gridKey = GlobalKey<MoviePosterGridState>();
  final _gridFocus = FocusNode(debugLabel: 'movie_category_grid');
  final _backFocus = FocusNode(debugLabel: 'movie_category_back');
  final _stateFocus = FocusNode(debugLabel: 'movie_category_state');

  final List<MovieItem> _movies = [];
  final Set<String> _keys = {};
  int _pages = 0;
  bool _ended = false;
  bool _loading = false;
  bool _failed = false;

  @visibleForTesting
  int get debugIndex => _gridKey.currentState?.index ?? 0;

  @visibleForTesting
  int get debugLoaded => _movies.length;

  /// Total de la categoría para el título; `null` hasta que llega (o si
  /// falla: el título queda sin número).
  int? _total;

  Future<void> _loadTotal() async {
    try {
      final total =
          await (widget.fetchTotal?.call() ??
              MoiamovApiService.instance.fetchShelfTotal(
                widget.category.columnId,
              ));
      if (mounted && total != null && total > 0) {
        setState(() => _total = total);
      }
    } catch (e) {
      debugPrint('⚠️ [Categoría] Total de ${widget.category.columnName}: $e');
    }
  }

  late final CategoryPageFetcher _fetch =
      widget.fetchPage ??
      (page) => MoiamovApiService.instance.fetchShelf(
        widget.category.columnId,
        page: page,
        pageSize: FeaturedMoviesProvider.shelfPageSize,
      );

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _add(initial.movies);
      _pages = initial.pages;
      _ended = initial.ended;
    }
    if (_movies.isEmpty) _loadMore();
    _loadTotal();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusContent());
  }

  @override
  void dispose() {
    _gridFocus.dispose();
    _backFocus.dispose();
    _stateFocus.dispose();
    super.dispose();
  }

  /// El contenido: la grilla o, sin películas, el aviso (vacío o error).
  void _focusContent() {
    if (!mounted) return;
    (_movies.isEmpty ? _stateFocus : _gridFocus).requestFocus();
  }

  /// Suma lo de su tipo (películas o series) sin repetidos.
  void _add(List<MovieItem> movies) {
    for (final movie in movies) {
      if (widget.series ? !movie.isSeries : !movie.isMovie) continue;
      if (_keys.add(MovieGridCatalog.keyOf(movie))) _movies.add(movie);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _ended) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final page = _pages + 1;
    List<MovieItem>? result;
    try {
      result = await _fetch(page);
    } catch (e) {
      debugPrint('⚠️ [Categoría] ${widget.category.columnName} p$page: $e');
    }
    if (!mounted) return;
    final hadMovies = _movies.isNotEmpty;
    setState(() {
      _loading = false;
      if (result == null) {
        _failed = true;
        return;
      }
      _add(result);
      _pages = page;
      if (result.length < FeaturedMoviesProvider.shelfPageSize) _ended = true;
    });
    // Sin películas antes (se mostraba "cargando"): el foco va a lo que
    // apareció, la grilla o el aviso de error/vacío, cuando ya está armado.
    if (!hadMovies) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusContent());
    }
  }

  void _open(MovieItem movie) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => movie.isSeries
            ? SeriesDetailScreen(series: movie)
            : MovieDetailScreen(movie: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Del ancho del rail del Inicio (8 + 48 + 4), con el botón
                  // centrado donde van sus íconos.
                  SizedBox(
                    width: 60,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        TvBackPill(
                          focusNode: _backFocus,
                          onKeyRight: _focusContent,
                          onKeyDown: _focusContent,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: _panel(scheme),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El mismo panel que Películas ([HomeMoviesArea]): la pestaña con el
  /// ícono y "Ver más - categoría", y adentro el título y la grilla con sus
  /// mismos márgenes.
  Widget _panel(ColorScheme scheme) {
    final tabTitle = LocaleKeys.movies_category_panel_title.tr(
      namedArgs: {'category': widget.category.columnName},
    );
    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      titles: [tabTitle],
      icons: const [MoaiIcons.tvAccordionMovies],
      svgIcons: [if (widget.series) MoaiIcons.seriesSvg else null],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) => LayoutBuilder(
        builder: (context, constraints) {
          // Como en Películas: lo que sobra de alto con dos filas va al
          // encabezado, así el hueco de abajo es el de la derecha.
          final colWidth =
              ((constraints.maxWidth -
                          _leftPadding -
                          _rightPadding -
                          4 * _columnGap) /
                      MoviePosterGridState.columns)
                  .clamp(100.0, 400.0);
          final cardHeight = TvMovieCard.heightForWidth(colWidth);
          final headerHeight =
              (constraints.maxHeight -
                      _listPadding -
                      2 * cardHeight -
                      _gap -
                      _rightPadding)
                  .clamp(44.0, 72.0);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // La grilla ya deja su relleno de arriba debajo del título.
              SizedBox(height: headerHeight, child: _header(scheme)),
              Expanded(child: _body(scheme)),
            ],
          );
        },
      ),
    );
  }

  static const double _leftPadding = 4.0;
  static const double _rightPadding = 14.0;
  static const double _gap = 12.0;
  static const double _listPadding = 8.0;

  /// Sin la pestaña de Buscar el panel es más ancho que el de Películas: ese
  /// ancho se reparte entre las columnas, así los pósters miden lo mismo que
  /// allá (entre filas sigue [_gap]).
  static const double _columnGap =
      _gap +
      (TvAccordionRowPreview.collapsedWidth + TvAccordionRowPreview.gap) /
          (MoviePosterGridState.columns - 1);

  /// Como el encabezado de cada categoría de Películas.
  Widget _header(ColorScheme scheme) {
    return Padding(
      // En Películas el título va dentro de la lista, después de su relleno
      // de arriba; acá la grilla pone ese relleno debajo del título.
      padding: const EdgeInsets.only(
        left: _leftPadding + 4,
        right: _rightPadding,
        bottom: 12 - _listPadding,
      ),
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
                  widget.category.columnName,
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
            if (_total case final total?) ...[
              const SizedBox(width: 10),
              // Sólido, del color de la sección en el rail.
              TvMetaPill(
                label: MoaiFormats.thousands(total),
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

  Widget _body(ColorScheme scheme) {
    if (_movies.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: TvEmptyStateCard(
          focusNode: _stateFocus,
          icon: _failed ? MoaiIcons.error : MoaiIcons.tvMoviesEmpty,
          message: _failed
              ? LocaleKeys.movies_category_error.tr(
                  namedArgs: {'category': widget.category.columnName},
                )
              : LocaleKeys.movies_category_empty.tr(),
          subtitle: _failed ? LocaleKeys.update_action_retry.tr() : null,
          onTap: _failed ? _loadMore : null,
          onFocusLeft: _backFocus.requestFocus,
        ),
      );
    }
    // Como en Buscar: sin scroll, dos filas enteras y los puntos al costado.
    // Los puntos se llevan su ancho de entre las columnas: los pósters miden
    // lo mismo que en Películas. Arriba y abajo, los rellenos de la lista.
    return Padding(
      padding: const EdgeInsets.only(top: _listPadding, bottom: _rightPadding),
      child: MoviePosterGrid(
        key: _gridKey,
        movies: _movies,
        focusNode: _gridFocus,
        leftPadding: _leftPadding,
        columnGap:
            _columnGap -
            MoviePosterGridState.dotsWidth / (MoviePosterGridState.columns - 1),
        windowRows: 2,
        onOpen: _open,
        loadingMore: _loading,
        loadFailed: _failed && !_ended,
        onNearEnd: _loadMore,
        onExitLeft: _backFocus.requestFocus,
      ),
    );
  }
}
