import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_grid_catalog.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:moai3/services/tmdb_trending_service.dart';

class _CatalogSectionState {
  List<MovieItem> items = [];
  List<CategoryColumn> categories = [];

  /// "Lo mejor del año" (sólo Películas): la fila de arriba de la grilla.
  List<MovieItem> bestOfYear = const [];
  bool isLoading = false;
  String? errorMessage;
  String? errorDetail;
  bool loadedOnce = false;
}

/// Una página ([FeaturedMoviesProvider.shelfPageSize] películas) de la
/// lista del servidor de una categoría (`getShelveData`); `null` si falla.
typedef ShelfFetcher =
    Future<List<MovieItem>?> Function(int columnId, int page);

/// Proveedor de catálogos para el rail (Destacados, Películas, Series).
class FeaturedMoviesProvider extends ChangeNotifier {
  /// [fetchShelf], [fetchShelfTotal] y [shelfWait] se reemplazan en los
  /// tests.
  FeaturedMoviesProvider({
    ShelfFetcher? fetchShelf,
    Future<int?> Function(int columnId)? fetchShelfTotal,
    this.shelfWait = const Duration(seconds: 5),
  }) : _fetchShelf =
           fetchShelf ??
           ((id, page) => MoiamovApiService.instance.fetchShelf(
             id,
             page: page,
             pageSize: shelfPageSize,
           )),
       _fetchShelfTotal =
           fetchShelfTotal ?? MoiamovApiService.instance.fetchShelfTotal;

  final Future<int?> Function(int columnId) _fetchShelfTotal;

  /// Categoría "Todos" de cada sección (en el servidor "All", toda la
  /// biblioteca), tomada del catálogo al cargarla.
  final Map<String, int> _allColumnIds = {};

  final Map<String, int> _libraryTotals = {};
  final Set<String> _libraryTotalLoading = {};

  /// Secciones cuyo total se pidió antes de que terminaran de cargar.
  final Set<String> _libraryTotalWanted = {};

  /// Películas en toda la biblioteca (Acerca de); `null` mientras no se sabe.
  int? get libraryTotal => libraryTotalFor(sectionMovies);

  /// El total de "Todos" de [section] (en Series cuenta **temporadas**:
  /// cada una es un ítem del portal); `null` mientras no se sabe o si la
  /// sección no tiene "Todos".
  int? libraryTotalFor(String section) => _libraryTotals[section];

  bool get libraryTotalLoading =>
      _libraryTotalLoading.contains(sectionMovies) ||
      (_libraryTotalWanted.contains(sectionMovies) && libraryTotal == null);

  /// Pide una vez por sesión el total de "Todos" de [section]. Si la sección
  /// todavía no cargó (o está cargando), lo pide apenas termina. Nunca falla.
  Future<void> loadLibraryTotal({String section = sectionMovies}) async {
    if (_libraryTotals.containsKey(section) ||
        _libraryTotalLoading.contains(section)) {
      return;
    }
    if (!isSectionAvailable(section)) return;
    final allId = _allColumnIds[section];
    if (allId == null) {
      // Ya cargó y no tiene "Todos": no hay total.
      if (loadedOnceFor(section) && !isLoadingFor(section)) {
        if (_libraryTotalWanted.remove(section)) notifyListeners();
        return;
      }
      final pending = _libraryTotalWanted.add(section);
      if (pending) notifyListeners();
      if (!isLoadingFor(section) && !loadedOnceFor(section)) {
        unawaited(loadSection(section));
      }
      return;
    }
    _libraryTotalLoading.add(section);
    notifyListeners();
    try {
      final total = await _fetchShelfTotal(allId);
      if (total != null) _libraryTotals[section] = total;
    } catch (e) {
      debugPrint('⚠️ [Catálogo] Total de la biblioteca ($section): $e');
    } finally {
      _libraryTotalLoading.remove(section);
      _libraryTotalWanted.remove(section);
      notifyListeners();
    }
  }

  /// Películas por página al completar categorías.
  static const int shelfPageSize = 30;

  /// Páginas como mucho por categoría al completarla.
  static const int _maxShelfPages = 3;

  static const String sectionFeatured = 'masnew_featured';
  static const String sectionMovies = 'masnew_movies';
  static const String sectionSeries = 'masnew_series';

  /// Cuánto espera la grilla de Películas a la fila de estrenos de TMDb.
  static const Duration _trendingWait = Duration(seconds: 3);

  /// Cuánto espera la grilla de Películas a las listas del servidor para
  /// completar las categorías sin repetidas. Corre a la par de TMDb.
  final Duration shelfWait;

  /// Pedidos a la vez al completar categorías.
  static const int _shelfConcurrency = 6;

  final ShelfFetcher _fetchShelf;

  /// Listas del servidor por `columnId` (las páginas pedidas, una tras otra),
  /// para toda la sesión: se descartan con un catálogo nuevo. Lo que falló
  /// no se guarda y se reintenta en la próxima carga.
  final Map<int, List<MovieItem>> _shelves = {};

  /// Páginas ya pedidas por categoría.
  final Map<int, int> _shelfPages = {};

  /// Categorías cuya lista ya no tiene más (vino una página corta).
  final Set<int> _shelfEnded = {};

  /// Categorías con un pedido en curso: no se piden dos veces.
  final Set<int> _shelfInFlight = {};

  /// Categorías de Series: de su lista del servidor se guardan las series
  /// (de las demás, las películas).
  final Set<int> _seriesColumns = {};

  /// Cambia con cada catálogo nuevo: un pedido que vuelve después no mezcla
  /// datos del catálogo anterior.
  int _shelfGeneration = 0;

  final Map<String, _CatalogSectionState> _sections = {};

  /// Secciones que el rail puede mostrar: las decide el arranque
  /// (login de este arranque + catálogo guardado).
  Set<String> _availableSections = const {};

  Set<String> get availableSections => _availableSections;

  bool isSectionAvailable(String section) =>
      _availableSections.contains(section);

  /// Resultado del arranque. Descarta lo cargado antes para releer el disco.
  void setAvailableSections(Set<String> sections) {
    _availableSections = Set.unmodifiable(sections);
    _sections.clear();
    _shelves.clear();
    _shelfPages.clear();
    _shelfEnded.clear();
    _shelfInFlight.clear();
    _seriesColumns.clear();
    _shelfGeneration++;
    _allColumnIds.clear();
    _libraryTotals.clear();
    notifyListeners();
  }

  /// Lo que ya bajó de la lista del servidor de una categoría (para que
  /// "Ver todas" arranque al instante y siga desde la página siguiente).
  /// `null` si todavía no se pidió nada.
  ({List<MovieItem> movies, int pages, bool ended})? shelfSnapshot(
    int columnId,
  ) {
    final movies = _shelves[columnId];
    if (movies == null) return null;
    return (
      movies: List.unmodifiable(movies),
      pages: _shelfPages[columnId] ?? 0,
      ended: _shelfEnded.contains(columnId),
    );
  }

  bool _canFetchMore(int columnId) =>
      !_shelfEnded.contains(columnId) &&
      !_shelfInFlight.contains(columnId) &&
      (_shelfPages[columnId] ?? 0) < _maxShelfPages;

  /// Pide la página siguiente de cada una de [columnIds] (de a
  /// [_shelfConcurrency]) y la suma a [_shelves]. Nunca falla: las que no
  /// contestaron se agregan a [failed].
  Future<void> _loadShelves(Set<int> columnIds, Set<int> failed) async {
    final pending = [
      for (final id in columnIds)
        if (_canFetchMore(id)) id,
    ];
    for (var i = 0; i < pending.length; i += _shelfConcurrency) {
      await Future.wait([
        for (final id in pending.skip(i).take(_shelfConcurrency))
          _loadNextPage(id, failed),
      ]);
    }
  }

  Future<void> _loadNextPage(int id, Set<int> failed) async {
    final generation = _shelfGeneration;
    final page = (_shelfPages[id] ?? 0) + 1;
    _shelfInFlight.add(id);
    try {
      final items = await _fetchShelf(id, page);
      if (generation != _shelfGeneration) return;
      if (items == null) {
        failed.add(id);
        return;
      }
      final series = _seriesColumns.contains(id);
      _shelves[id] = [
        ...?_shelves[id],
        ...items.where((m) => series ? m.isSeries : m.isMovie),
      ];
      _shelfPages[id] = page;
      // Con lo que mandó el servidor: lo filtrado no dice si hay más.
      if (items.length < shelfPageSize) _shelfEnded.add(id);
    } catch (e) {
      failed.add(id);
      debugPrint('⚠️ [Catálogo] Lista de la categoría $id: $e');
    } finally {
      if (generation == _shelfGeneration) _shelfInFlight.remove(id);
    }
  }

  /// Espera [work] hasta [deadline]; si no llega, sigue (lo que llegue
  /// después queda en [_shelves] para la próxima carga).
  static Future<void> _until(Future<void> work, DateTime deadline) async {
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) return;
    try {
      await work.timeout(left);
    } on TimeoutException {
      debugPrint('⚠️ [Catálogo] Sin respuesta a tiempo de algunas categorías');
    }
  }

  /// Grilla de Películas sin repetidas (SPEC-44 §3.2): completa con las
  /// listas del servidor las categorías que pierden películas. [firstRound]
  /// ya pidió las que se veían venir; después, por vueltas, se pide la
  /// página siguiente de las que siguen cortas (p. ej. por la fila de TMDb o
  /// por lo que tomaron otras al completarse), hasta [deadline].
  Future<List<CategoryColumn>> _uniqueMovieGrid(
    List<CategoryColumn> categories, {
    required Set<int> serverColumns,
    required Future<void> firstRound,
    required Set<int> failed,
    required DateTime deadline,
  }) async {
    await _until(firstRound, deadline);
    // Todas las del servidor se pueden ver completas: llevan "Ver todas".
    List<CategoryColumn> build() => MovieGridCatalog.build(
      categories,
      extras: _shelves,
      withShowAll: serverColumns,
    );
    int target(int columnId) =>
        MovieGridCatalog.targetFor(columnId, withShowAll: serverColumns);

    var grid = build();
    for (var round = 0; round < _maxShelfPages; round++) {
      if (!DateTime.now().isBefore(deadline)) break;
      final shown = {for (final c in grid) c.columnId: c.movies.length};
      final short = {
        for (final c in categories)
          if (serverColumns.contains(c.columnId) &&
              !failed.contains(c.columnId) &&
              _canFetchMore(c.columnId) &&
              (shown[c.columnId] ?? 0) < target(c.columnId))
            c.columnId,
      };
      if (short.isEmpty) break;
      await _until(_loadShelves(short, failed), deadline);
      grid = build();
    }
    final before = categories.fold<int>(0, (n, c) => n + c.movies.length);
    final after = grid.fold<int>(0, (n, c) => n + c.movies.length);
    final full = grid
        .where((c) => c.movies.length == target(c.columnId))
        .length;
    final unique = {
      for (final c in grid) ...c.movies.map(MovieGridCatalog.keyOf),
    }.length;
    final incomplete = [
      for (final c in grid)
        if (c.movies.length < target(c.columnId))
          '${c.columnName} (${c.movies.length})',
    ];
    debugPrint(
      '🎬 [Catálogo] Grilla sin repetidas: $after películas en '
      '${grid.length} categorías ($full completas; antes $before con '
      'repetidas; ${_shelves.length} listas del servidor; '
      'repetidas que quedan: ${after - unique})'
      '${incomplete.isEmpty ? '' : '; incompletas: ${incomplete.join(', ')}'}',
    );
    return grid;
  }

  _CatalogSectionState _stateFor(String section) =>
      _sections.putIfAbsent(section, _CatalogSectionState.new);

  List<MovieItem> itemsFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return items;
    }
    return _stateFor(section).items;
  }

  List<CategoryColumn> categoriesFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return categories;
    }
    return _stateFor(section).categories;
  }

  List<MovieItem> bestOfYearFor(String section) =>
      _sections[section]?.bestOfYear ?? const [];

  bool isLoadingFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return isLoading;
    }
    return _stateFor(section).isLoading;
  }

  String? errorMessageFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return errorMessage;
    }
    return _stateFor(section).errorMessage;
  }

  String? errorDetailFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return errorDetail;
    }
    return _stateFor(section).errorDetail;
  }

  bool loadedOnceFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return loadedOnce;
    }
    return _stateFor(section).loadedOnce;
  }

  // Retrocompatibilidad con getters existentes apuntando a sectionFeatured:
  List<MovieItem> get items => _stateFor(sectionFeatured).items;
  List<CategoryColumn> get categories => _stateFor(sectionFeatured).categories;
  bool get isLoading => _stateFor(sectionFeatured).isLoading;
  String? get errorMessage => _stateFor(sectionFeatured).errorMessage;
  String? get errorDetail => _stateFor(sectionFeatured).errorDetail;
  bool get loadedOnce => _stateFor(sectionFeatured).loadedOnce;

  /// Carga `masnew_featured` desde el catálogo guardado.
  Future<void> loadFeatured({bool force = false}) =>
      loadSection(sectionFeatured, force: force);

  /// Carga cualquier sección del catálogo (`masnew_featured`, `masnew_movies`, `masnew_series`).
  Future<void> loadSection(String section, {bool force = false}) async {
    final state = _stateFor(section);
    if (state.isLoading) return;
    if (!force && state.loadedOnce && state.items.isNotEmpty) return;

    state.isLoading = true;
    state.errorMessage = null;
    state.errorDetail = null;
    notifyListeners();

    try {
      final result = await MoiamovApiService.instance.loadPersistedCatalog(
        section,
      );
      final columns = result?.categories ?? const <CategoryColumn>[];
      // "All" llega como "Todos" (CategoryColumn.fromJson).
      final allId = columns
          .where((c) => normalizeText(c.columnName) == 'todos')
          .map((c) => c.columnId)
          .firstOrNull;
      if (allId != null) {
        _allColumnIds[section] = allId;
      } else {
        _allColumnIds.remove(section);
      }
      // Los tráileres del catálogo no se muestran en ningún lado (los
      // adelantos del Inicio vienen de TMDb).
      final flat = <MovieItem>[];
      final seen = <String>{};
      for (final column in columns) {
        for (final movie in column.movies) {
          if (movie.isCatalogTrailer) continue;
          final key = movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}|${movie.poster}';
          if (seen.add(key)) flat.add(movie);
        }
      }
      state.items = flat;
      var categories = [
        for (final column in columns)
          if (column.movies.where((m) => !m.isCatalogTrailer).toList()
              case final movies when movies.isNotEmpty)
            CategoryColumn(
              columnId: column.columnId,
              columnName: column.columnName,
              code: column.code,
              movies: movies,
            ),
      ];

      // Las listas para completar sin repetidas se piden ya, a la par de
      // TMDb; la grilla las espera antes de mostrarse (después correría el
      // foco).
      final serverColumns = {for (final c in categories) c.columnId};
      final shelfDeadline = DateTime.now().add(shelfWait);
      final failedShelves = <int>{};
      // Películas y Series: sin repetidas, completas y con "Ver todas".
      final uniqueGrid = section == sectionMovies || section == sectionSeries;
      if (section == sectionSeries) _seriesColumns.addAll(serverColumns);
      // Primera página de las que se ve que van a perder películas y todavía
      // no tienen nada; las páginas siguientes, sólo si siguen cortas.
      final firstShelves = uniqueGrid
          ? _loadShelves(
              MovieGridCatalog.columnsNeedingMore(
                categories,
                fetchable: serverColumns,
                withShowAll: serverColumns,
              ).where((id) => !_shelves.containsKey(id)).toSet(),
              failedShelves,
            )
          : Future<void>.value();

      if (section == sectionMovies) {
        // A la par de Estrenos (comparten la caché de TMDb); sin TMDb sale
        // con el respaldo local.
        final bestOfYear = TmdbTrendingService.instance.buildBestOfYear(
          allCatalogMovies: flat,
          wait: _trendingWait,
        );
        try {
          // La grilla espera a TMDb como mucho [_trendingWait]: después sale
          // sin la fila (sumarla más tarde correría el foco). Lo que llegue
          // tarde queda en caché para la próxima carga.
          final trendingRow = await TmdbTrendingService.instance
              .buildTrendingRow(
                allCatalogMovies: flat,
                existingCategories: categories,
              )
              .timeout(_trendingWait);
          if (trendingRow.movies.isNotEmpty) {
            categories = [trendingRow, ...categories];
          }
        } catch (e) {
          debugPrint('⚠️ [TMDB] Error al armar fila de estrenos: $e');
        }
        // "Mejor puntuadas" (local) después de Estrenos y antes de las del
        // servidor; el armado sin repetidas la trata como cualquier otra.
        final topRated = MovieGridCatalog.topRated(
          flat,
          name: LocaleKeys.movies_category_top_rated.tr(),
        );
        if (topRated != null) {
          final firstServer = categories.indexWhere(
            (c) => serverColumns.contains(c.columnId),
          );
          categories = [...categories]
            ..insert(
              firstServer < 0 ? categories.length : firstServer,
              topRated,
            );
        }
        categories = await _uniqueMovieGrid(
          categories,
          serverColumns: serverColumns,
          firstRound: firstShelves,
          failed: failedShelves,
          deadline: shelfDeadline,
        );
        state.bestOfYear = await bestOfYear;
      } else if (section == sectionSeries) {
        // Sin las filas de TMDb (Estrenos, Mejor puntuadas): son de películas.
        categories = await _uniqueMovieGrid(
          categories,
          serverColumns: serverColumns,
          firstRound: firstShelves,
          failed: failedShelves,
          deadline: shelfDeadline,
        );
      }

      state.categories = categories;
      state.loadedOnce = true;
    } catch (e) {
      state.errorMessage = LocaleKeys.movies_load_error;
      state.errorDetail = '$e';
      state.items = [];
      state.categories = [];
      state.loadedOnce = true;
    } finally {
      state.isLoading = false;
      notifyListeners();
      // Acerca de pidió el total mientras Películas cargaba.
      if (_libraryTotalWanted.contains(section)) {
        unawaited(loadLibraryTotal(section: section));
      }
    }
  }
}
