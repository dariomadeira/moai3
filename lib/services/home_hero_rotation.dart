import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Qué va en la tarjeta grande de la fila destacada del Inicio: un arranque
/// las películas (con dos series de póster al lado) y el siguiente las
/// series (con dos películas). Se elige una vez por arranque.
class HomeHeroLead {
  HomeHeroLead._();

  static final HomeHeroLead instance = HomeHeroLead._();

  static const String _key = 'home_hero_lead_series';

  bool _loaded = false;
  bool _seriesLead = false;

  bool get isLoaded => _loaded;

  /// En este arranque la tarjeta grande es de series. Antes de [load], no.
  bool get seriesLead => _seriesLead;

  /// Como un arranque nuevo.
  @visibleForTesting
  void debugReset() {
    _loaded = false;
    _seriesLead = false;
  }

  /// Lee qué fue la vez anterior, elige lo otro (la primera vez, películas)
  /// y lo guarda.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _seriesLead = !(prefs.getBool(_key) ?? true);
      await prefs.setBool(_key, _seriesLead);
    } catch (e) {
      debugPrint('[HomeHeroLead] No se pudo leer o guardar: $e');
    }
    _loaded = true;
  }
}

/// Con qué título empieza una tarjeta destacada: la del Inicio elige el que
/// sigue al último que se vio la vez anterior, así cada arranque muestra
/// otro (y recorre todos). Se elige una vez por arranque: volver al Inicio
/// no lo cambia. Hay una rotación para películas ([movies]) y otra para
/// series ([series]).
///
/// La tarjeta grande de arriba de Películas o Series arranca con el mismo
/// que eligió el Inicio, si está en su lista ([chosenIndex]); pasar con las
/// flechas en cualquiera de las dos lo recuerda para el próximo arranque.
class HomeHeroRotation {
  HomeHeroRotation._(this._key);

  static final HomeHeroRotation movies = HomeHeroRotation._(
    'home_hero_last_movie',
  );
  static final HomeHeroRotation series = HomeHeroRotation._(
    'home_hero_last_series',
  );

  final String _key;

  String? _lastId;
  bool _loaded = false;

  /// El elegido en este arranque.
  String? _startId;

  bool get isLoaded => _loaded;

  /// Como un arranque nuevo.
  @visibleForTesting
  void debugReset() {
    _lastId = null;
    _loaded = false;
    _startId = null;
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastId = prefs.getString(_key);
    } catch (e) {
      debugPrint('[HomeHeroRotation] No se pudo leer: $e');
    }
    _loaded = true;
  }

  /// Lugar en [items] del título con que empieza la tarjeta del Inicio. La
  /// primera vez lo elige (el siguiente al último visto; sin dato, el
  /// primero) y lo guarda como visto.
  int startIndex(List<MovieItem> items) {
    if (items.isEmpty) return 0;
    if (_startId == null) {
      final last = items.indexWhere((m) => m.contentId == _lastId);
      final start = items[(last + 1) % items.length];
      _startId = start.contentId;
      remember(start);
    }
    final index = items.indexWhere((m) => m.contentId == _startId);
    return index < 0 ? 0 : index;
  }

  /// Lugar en [items] (la tarjeta grande de una sección) del elegido en este
  /// arranque o, si no está, del último visto; si ninguno está, el primero.
  int chosenIndex(List<MovieItem> items) {
    for (final id in [_startId, _lastId]) {
      if (id == null) continue;
      final index = items.indexWhere((m) => m.contentId == id);
      if (index >= 0) return index;
    }
    return 0;
  }

  /// [item] es el último que se vio en una tarjeta (al pasar con las
  /// flechas).
  Future<void> remember(MovieItem item) async {
    _lastId = item.contentId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, item.contentId);
    } catch (e) {
      debugPrint('[HomeHeroRotation] No se pudo guardar: $e');
    }
  }
}
