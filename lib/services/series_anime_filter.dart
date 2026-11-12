import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Ocultar anime de series" (Ajustes › Películas y series, SPEC-39 §3.1).
///
/// El portal no tiene categoría de anime: viene mezclado con el resto, con
/// el género "Animation" (que también llevan Bob Esponja o Scooby-Doo). Por
/// eso, de cada serie animada se pide una vez el detalle para saber el país
/// ([SeriesSeasonDetail.originalCountry]) y se ocultan las de Japón, China
/// y Corea. Mientras no se sabe, la serie animada queda oculta (mejor que
/// aparezca un anime un rato). El país se guarda por serie (todas sus
/// temporadas) y no se vuelve a pedir.
class SeriesAnimeFilter extends ChangeNotifier {
  SeriesAnimeFilter._();

  static final SeriesAnimeFilter instance = SeriesAnimeFilter._();

  static const String _key = 'series_origin_v1';

  bool _enabled = false;

  /// El ajuste. Lo pone [TvSettingsProvider].
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    version++;
    notifyListeners();
    if (value) _ensureLoaded();
  }

  /// Cambia cada vez que cambia qué se oculta: el catálogo vuelve a armar
  /// la grilla.
  int version = 0;

  /// País por serie (título normalizado, sin "T2"); `''` si el portal no
  /// dijo.
  final Map<String, String> _origins = {};
  Future<void>? _loading;
  bool _resolving = false;

  /// Reemplaza el pedido del detalle cuando [resolve] no recibe uno (el
  /// catálogo lo llama sin él). Los tests no salen a la red.
  @visibleForTesting
  Future<SeriesSeasonDetail?> Function(String contentId)? debugFetchSeason;

  @visibleForTesting
  void resetForTest() {
    debugFetchSeason = null;
    _enabled = false;
    version = 0;
    _origins.clear();
    _loading = null;
    _resolving = false;
  }

  static String _keyOf(MovieItem item) =>
      normalizeText(SeriesSeasonDetail.seriesTitle(item.name));

  static bool _hasTag(MovieItem item, String tag) =>
      (item.tags ?? '').split(',').any((t) => t.trim().toLowerCase() == tag);

  /// Lleva el género "Animation" (o "Anime").
  static bool isAnimated(MovieItem item) =>
      _hasTag(item, 'animation') || _hasTag(item, 'anime');

  /// Anime: de Japón, China o Corea.
  static bool isAnimeCountry(String country) =>
      RegExp(r'japan|china|korea', caseSensitive: false).hasMatch(country);

  /// Con el ajuste prendido, [item] no se muestra: una serie animada de
  /// Japón, China o Corea, o una animada de la que todavía no se sabe.
  bool hides(MovieItem item) {
    if (!_enabled || !item.isSeries || !isAnimated(item)) return false;
    if (_hasTag(item, 'anime')) return true;
    final country = _origins[_keyOf(item)];
    return country == null || isAnimeCountry(country);
  }

  /// Las series animadas de [items] de las que no se sabe el país.
  List<MovieItem> pending(Iterable<MovieItem> items) {
    final keys = <String>{};
    return [
      for (final item in items)
        if (item.isSeries &&
            isAnimated(item) &&
            !_hasTag(item, 'anime') &&
            !_origins.containsKey(_keyOf(item)) &&
            keys.add(_keyOf(item)))
          item,
    ];
  }

  /// Pide el país de las series animadas de [items] que no se conocen, de a
  /// una. Avisa cada 10 y al final. Lo que no contesta se vuelve a pedir la
  /// próxima.
  Future<void> resolve(
    Iterable<MovieItem> items, {
    Future<SeriesSeasonDetail?> Function(String contentId)? fetchSeason,
  }) async {
    if (!_enabled || _resolving) return;
    await _ensureLoaded();
    final todo = pending(items);
    if (todo.isEmpty) return;
    _resolving = true;
    final fetch =
        fetchSeason ??
        debugFetchSeason ??
        MoiamovApiService.instance.fetchSeriesSeason;
    var found = 0;
    try {
      for (final item in todo) {
        if (!_enabled) break;
        final detail = await fetch(item.contentId);
        if (detail == null) continue;
        _origins[_keyOf(item)] = detail.originalCountry ?? '';
        if (++found % 10 == 0) await _changed();
      }
    } finally {
      _resolving = false;
      if (found % 10 != 0) await _changed();
    }
  }

  Future<void> _changed() async {
    version++;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_origins));
    } catch (e) {
      debugPrint('⚠️ [Anime] No se pudo guardar: $e');
    }
  }

  Future<void> _ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      for (final entry in json.entries) {
        _origins.putIfAbsent('${entry.key}', () => '${entry.value}');
      }
      if (_origins.isNotEmpty) {
        version++;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ [Anime] No se pudo leer: $e');
    }
  }
}
