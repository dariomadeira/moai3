import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Interesantes": películas guardadas para ver después, la última agregada
/// primero.
///
/// Guarda la película entera para que el Inicio pueda mostrarla y abrir su
/// detalle sin esperar el catálogo.
class MovieWatchlistService extends ChangeNotifier {
  MovieWatchlistService._();

  static final MovieWatchlistService instance = MovieWatchlistService._();

  static const String _key = 'movie_watchlist';

  List<MovieItem> _movies = const [];
  Future<void>? _loading;

  List<MovieItem> get movies => _movies;

  bool contains(String contentId) =>
      _movies.any((m) => m.contentId == contentId);

  /// Lee la lista guardada una sola vez; las llamadas siguientes no releen.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _movies = List.unmodifiable(
        (prefs.getStringList(_key) ?? const []).map(_decode).nonNulls,
      );
    } catch (e) {
      debugPrint('[MovieWatchlistService] No se pudo leer la lista: $e');
    }
    notifyListeners();
  }

  static MovieItem? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final movie = MovieItem.fromJson(json);
      return movie.contentId.isEmpty ? null : movie;
    } catch (_) {
      return null;
    }
  }

  /// Agrega o quita [movie]. Devuelve si quedó en la lista.
  Future<bool> toggle(MovieItem movie) async {
    await ensureLoaded();
    final added = !contains(movie.contentId);
    await _save([
      if (added) movie,
      ..._movies.where((m) => m.contentId != movie.contentId),
    ]);
    return added;
  }

  Future<void> remove(String contentId) async {
    await ensureLoaded();
    if (!contains(contentId)) return;
    await _save(_movies.where((m) => m.contentId != contentId).toList());
  }

  /// Vacía la lista.
  Future<void> clear() async {
    await ensureLoaded();
    if (_movies.isEmpty) return;
    await _save(const []);
  }

  Future<void> _save(List<MovieItem> movies) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      movies.map((m) => jsonEncode(m.toJson())).toList(),
    );
    _movies = List.unmodifiable(movies);
    notifyListeners();
  }

  /// Sólo para tests: olvida lo cargado para releer las preferencias.
  @visibleForTesting
  void resetForTest() {
    _movies = const [];
    _loading = null;
  }
}
