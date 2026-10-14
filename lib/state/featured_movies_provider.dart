import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';

/// Catálogo plano de destacados (`masnew_featured`) para el rail Películas.
class FeaturedMoviesProvider extends ChangeNotifier {
  List<MovieItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _loadedOnce = false;

  List<MovieItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get loadedOnce => _loadedOnce;

  /// Carga `masnew_featured` desde persistido/bundled (sin asumir [cachedCatalog]).
  Future<void> loadFeatured({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _loadedOnce && _items.isNotEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await MoiamovApiService.instance.loadSavedOrBundled(
        section: 'masnew_featured',
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
      _items = flat;
      _loadedOnce = true;
    } catch (e) {
      _errorMessage = 'Error al cargar destacados: $e';
      _items = [];
      _loadedOnce = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
