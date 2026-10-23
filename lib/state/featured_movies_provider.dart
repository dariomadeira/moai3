import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/tmdb_trending_service.dart';

class _CatalogSectionState {
  List<MovieItem> items = [];
  List<CategoryColumn> categories = [];
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

  final Map<String, _CatalogSectionState> _sections = {};

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

  /// Carga `masnew_featured` desde persistido/bundled.
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
      final result = await MoiamovApiService.instance.loadSavedOrBundled(
        section: section,
      );
      final flat = <MovieItem>[];
      final seen = <String>{};
      for (final column in result.categories) {
        for (final movie in column.movies) {
          final key = movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}|${movie.poster}';
          if (seen.add(key)) {
            flat.add(movie);
          }
        }
      }
      state.items = flat;
      var categories =
          result.categories.where((c) => c.movies.isNotEmpty).toList();

      if (section == sectionMovies) {
        try {
          final trendingRow = await TmdbTrendingService.instance.buildTrendingRow(
            allCatalogMovies: flat,
            existingCategories: categories,
          );
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
      state.loadedOnce = true;
    } finally {
      state.isLoading = false;
      notifyListeners();
    }
  }
}
