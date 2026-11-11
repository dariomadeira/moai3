import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una serie marcada: la temporada con la que se abre (su ficha, para
/// mostrarla en el Inicio sin el catálogo) y todas sus temporadas, para
/// reconocerla se entre por la que se entre (cada temporada es un ítem del
/// portal y algunas vienen repetidas en dos versiones).
class SeriesWatchlistEntry {
  const SeriesWatchlistEntry({required this.item, required this.seasonIds});

  /// La serie como película: `contentId` de la temporada que abre el
  /// detalle y el nombre de la serie (sin "T2").
  final MovieItem item;
  final Set<String> seasonIds;

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'seasonIds': seasonIds.toList(),
  };

  static SeriesWatchlistEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final raw = json['item'];
    if (raw is! Map<String, dynamic>) return null;
    final item = MovieItem.fromJson(raw);
    if (item.contentId.isEmpty) return null;
    return SeriesWatchlistEntry(
      item: item,
      seasonIds: {
        item.contentId,
        for (final id in (json['seasonIds'] as List?) ?? const []) '$id',
      },
    );
  }
}

/// "Series marcadas": las series guardadas para ver después, la última
/// marcada primero. Como [MovieWatchlistService] pero de series: cuando una
/// se empieza a ver sale de acá (pasa a "Seguir series").
class SeriesWatchlistService extends ChangeNotifier {
  SeriesWatchlistService._();

  static final SeriesWatchlistService instance = SeriesWatchlistService._();

  static const String _key = 'series_watchlist';

  List<SeriesWatchlistEntry> _entries = const [];
  Future<void>? _loading;

  List<SeriesWatchlistEntry> get entries => _entries;

  /// Las series (como películas) para la tarjeta del Inicio.
  List<MovieItem> get items => [for (final e in _entries) e.item];

  /// Está marcada la serie de alguna de [seasonIds].
  bool contains(Iterable<String> seasonIds) =>
      _entryOf(seasonIds.toSet()) != null;

  SeriesWatchlistEntry? _entryOf(Set<String> seasonIds) =>
      _entries.where((e) => e.seasonIds.any(seasonIds.contains)).firstOrNull;

  /// Lee la lista guardada una sola vez; las llamadas siguientes no releen.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _entries = List.unmodifiable(
        (prefs.getStringList(_key) ?? const []).map((raw) {
          try {
            return SeriesWatchlistEntry.fromJson(jsonDecode(raw));
          } catch (_) {
            return null;
          }
        }).nonNulls,
      );
    } catch (e) {
      debugPrint('[SeriesWatchlistService] No se pudo leer la lista: $e');
    }
    notifyListeners();
  }

  /// Marca o desmarca la serie de [item] (con todas sus [seasonIds]).
  /// Devuelve si quedó marcada.
  Future<bool> toggle(MovieItem item, Iterable<String> seasonIds) async {
    await ensureLoaded();
    final ids = {item.contentId, ...seasonIds};
    final current = _entryOf(ids);
    await _save([
      if (current == null) SeriesWatchlistEntry(item: item, seasonIds: ids),
      ..._entries.where((e) => e != current),
    ]);
    return current == null;
  }

  /// Desmarca la serie de alguna de [seasonIds] (si estaba).
  Future<void> remove(Iterable<String> seasonIds) async {
    await ensureLoaded();
    final current = _entryOf(seasonIds.toSet());
    if (current == null) return;
    await _save(_entries.where((e) => e != current).toList());
  }

  /// Vacía la lista.
  Future<void> clear() async {
    await ensureLoaded();
    if (_entries.isEmpty) return;
    await _save(const []);
  }

  Future<void> _save(List<SeriesWatchlistEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
    _entries = List.unmodifiable(entries);
    notifyListeners();
  }

  /// Sólo para tests: olvida lo cargado para releer las preferencias.
  @visibleForTesting
  void resetForTest() {
    _entries = const [];
    _loading = null;
  }
}
