import 'package:flutter/foundation.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Últimas búsquedas de películas, la más nueva primero (SPEC-45 §3.2).
class MovieSearchHistory {
  static const String _key = 'movie_search_history';
  static const int maxEntries = 10;

  List<String> _entries = const [];

  List<String> get entries => _entries;

  Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _entries = List.unmodifiable(prefs.getStringList(_key) ?? const []);
    } catch (e) {
      debugPrint('[MovieSearchHistory] No se pudo leer: $e');
    }
    return _entries;
  }

  /// Pone [query] primero. Una igual (sin importar tildes ni mayúsculas) se
  /// reemplaza en vez de repetirse.
  Future<List<String>> remember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return _entries;
    final key = normalizeText(trimmed);
    _entries = List.unmodifiable(
      [
        trimmed,
        ..._entries.where((e) => normalizeText(e) != key),
      ].take(maxEntries),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _entries);
    } catch (e) {
      debugPrint('[MovieSearchHistory] No se pudo guardar: $e');
    }
    return _entries;
  }
}
