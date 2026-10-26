import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/tmdb_trending_service.dart';

class _CatalogSectionState {
  List<MovieItem> items = [];
  List<CategoryColumn> categories = [];

  /// Adelantos de la sección, fuera de [items] y [categories].
  List<MovieItem> trailers = const [];
  bool isLoading = false;
  String? errorMessage;
  String? errorDetail;
  bool loadedOnce = false;
}

/// Proveedor de catálogos para el rail (Destacados, Películas, Series).
class FeaturedMoviesProvider extends ChangeNotifier {
  static const String sectionFeatured = 'masnew_featured';
  static const String sectionMovies = 'masnew_movies';
  static const String sectionSeries = 'masnew_series';

  /// Cuánto espera la grilla de Películas a la fila de estrenos de TMDb.
  static const Duration _trendingWait = Duration(seconds: 3);

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
    notifyListeners();
  }

  _CatalogSectionState _stateFor(String section) =>
      _sections.putIfAbsent(section, _CatalogSectionState.new);

  List<MovieItem> itemsFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return items;
    }
    return _stateFor(section).items;
  }

  /// Adelantos (tráileres) de la sección: no están en la grilla, los muestra
  /// la tarjeta "Adelantos" del Inicio.
  List<MovieItem> trailersFor(String section) =>
      _sections[section]?.trailers ?? const [];

  List<CategoryColumn> categoriesFor(String section) {
    if (section == sectionFeatured && !_sections.containsKey(section)) {
      return categories;
    }
    return _stateFor(section).categories;
  }

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
      final result =
          await MoiamovApiService.instance.loadPersistedCatalog(section);
      final columns = result?.categories ?? const <CategoryColumn>[];
      // Los adelantos (tráileres) no van en la grilla: tienen su propia
      // tarjeta en el Inicio ([trailersFor]).
      final flat = <MovieItem>[];
      final trailers = <MovieItem>[];
      final seen = <String>{};
      for (final column in columns) {
        for (final movie in column.movies) {
          final key = movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}|${movie.poster}';
          if (seen.add(key)) {
            (movie.isTrailer ? trailers : flat).add(movie);
          }
        }
      }
      state.items = flat;
      state.trailers = trailers;
      var categories = [
        for (final column in columns)
          if (column.movies.where((m) => !m.isTrailer).toList()
              case final movies when movies.isNotEmpty)
            CategoryColumn(
              columnId: column.columnId,
              columnName: column.columnName,
              code: column.code,
              movies: movies,
            ),
      ];

      if (section == sectionMovies) {
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
      }

      state.categories = categories;
      state.loadedOnce = true;
    } catch (e) {
      state.errorMessage = LocaleKeys.movies_load_error;
      state.errorDetail = '$e';
      state.items = [];
      state.categories = [];
      state.trailers = const [];
      state.loadedOnce = true;
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }
}
