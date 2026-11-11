import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Con qué película empieza la tarjeta destacada del Inicio: la que sigue a
/// la última que se vio en la vez anterior, así cada arranque muestra otra
/// (y recorre todas). Se elige una vez por arranque: volver al Inicio no la
/// cambia.
class HomeHeroRotation {
  HomeHeroRotation._();

  static const String _key = 'home_hero_last_movie';

  static String? _lastId;
  static bool _loaded = false;

  /// La elegida en este arranque.
  static String? _startId;

  static bool get isLoaded => _loaded;

  /// Como un arranque nuevo.
  @visibleForTesting
  static void debugReset() {
    _lastId = null;
    _loaded = false;
    _startId = null;
  }

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastId = prefs.getString(_key);
    } catch (e) {
      debugPrint('[HomeHeroRotation] No se pudo leer: $e');
    }
    _loaded = true;
  }

  /// Lugar en [movies] de la película con que empieza la tarjeta. La primera
  /// vez la elige (la siguiente a la última vista; sin dato, la primera) y
  /// la guarda como vista.
  static int startIndex(List<MovieItem> movies) {
    if (movies.isEmpty) return 0;
    if (_startId == null) {
      final last = movies.indexWhere((m) => m.contentId == _lastId);
      final start = movies[(last + 1) % movies.length];
      _startId = start.contentId;
      remember(start);
    }
    final index = movies.indexWhere((m) => m.contentId == _startId);
    return index < 0 ? 0 : index;
  }

  /// [movie] es la última que se vio en la tarjeta (al pasar con las
  /// flechas).
  static Future<void> remember(MovieItem movie) async {
    _lastId = movie.contentId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, movie.contentId);
    } catch (e) {
      debugPrint('[HomeHeroRotation] No se pudo guardar: $e');
    }
  }
}
