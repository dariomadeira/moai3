import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
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
import 'package:moai3/widgets/tv_common/moai_glass.dart';
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
  });

  final CategoryColumn category;

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

  void _add(List<MovieItem> movies) {
    for (final movie in movies) {
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
    if (movie.isSeries) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
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
                  SizedBox(
                    width: 54,
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

  /// El panel de cristal con el título y la grilla (como la de Películas).
  Widget _panel(ColorScheme scheme) {
    final glass = MoaiGlassScope.enabledOf(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(scheme),
        Expanded(child: _body(scheme)),
      ],
    );
    if (glass) {
      return MoaiGlass(
        borderRadius: 16,
        solid: true,
        elevated: false,
        child: content,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: content,
    );
  }

  Widget _header(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.category.columnName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.display(
                context,
                fontSize: 22,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (_total case final total?) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: MoaiGlassScope.enabledOf(context)
                  ? moaiGlassChipDecoration(scheme, radius: 10)
                  : BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
              child: Text(
                LocaleKeys.movies_count.tr(
                  namedArgs: {'count': MoaiFormats.thousands(total)},
                ),
                style: MoaiText.body(
                  context,
                  fontSize: 12,
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
    return MoviePosterGrid(
      key: _gridKey,
      movies: _movies,
      focusNode: _gridFocus,
      onOpen: _open,
      loadingMore: _loading,
      loadFailed: _failed && !_ended,
      onNearEnd: _loadMore,
      onExitLeft: _backFocus.requestFocus,
    );
  }
}
