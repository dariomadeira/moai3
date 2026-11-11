import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/tmdb_trailers_service.dart';

/// Adelantos del Inicio: los [count] trailers de YouTube publicados más
/// recientemente de las películas en cartelera y por estrenarse (TMDb).
///
/// Lo último armado se guarda en disco y se muestra al instante al arrancar;
/// cada [listTtl] se renueva en segundo plano. El trailer de cada película se
/// recuerda [pickTtl]: al renovar sólo se piden las nuevas. Si TMDb no
/// contesta, quedan los de antes.
class HomeTrailersProvider extends ChangeNotifier {
  /// [service] y [now] se reemplazan en los tests.
  HomeTrailersProvider(
    this._prefs, {
    TmdbTrailersService? service,
    DateTime Function()? now,
  }) : _service = service ?? TmdbTrailersService(),
       _now = now ?? DateTime.now {
    _readCache();
  }

  final AppPreferences _prefs;
  final TmdbTrailersService _service;
  final DateTime Function() _now;

  static const String _cacheKey = 'home_trailers_v1';

  static const int count = 6;
  static const Duration listTtl = Duration(hours: 12);
  static const Duration pickTtl = Duration(hours: 24);

  /// Pedidos a TMDb a la vez al renovar.
  static const int _concurrency = 6;

  /// Candidatas de la última vez (ids de TMDb).
  List<int> _candidates = const [];

  /// Trailer por película: `null` si TMDb dijo que no tiene.
  final Map<int, ({DateTime checkedAt, TrailerPick? pick})> _picks = {};

  DateTime? _savedAt;
  bool _refreshing = false;

  List<MovieItem> _trailers = const [];
  List<MovieItem> get trailers => _trailers;

  /// Renueva si lo guardado tiene más de [listTtl] (o no hay nada). Se puede
  /// llamar seguido: si está al día o ya está renovando, no hace nada.
  Future<void> load() async {
    if (_refreshing) return;
    final savedAt = _savedAt;
    if (savedAt != null && _now().difference(savedAt) < listTtl) return;
    _refreshing = true;
    try {
      await _refresh();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refresh() async {
    final ids = await _service.candidateIds();
    if (ids == null || ids.isEmpty) return;
    final now = _now();
    bool known(int id) {
      final checkedAt = _picks[id]?.checkedAt;
      return checkedAt != null && now.difference(checkedAt) < pickTtl;
    }

    final pending = [
      for (final id in ids)
        if (!known(id)) id,
    ];
    for (var i = 0; i < pending.length; i += _concurrency) {
      final batch = pending.skip(i).take(_concurrency).toList();
      final results = await Future.wait(batch.map(_service.pickFor));
      for (var j = 0; j < batch.length; j++) {
        // Lo que no contestó queda como estaba (se reintenta la próxima).
        if (results[j].answered) {
          _picks[batch[j]] = (checkedAt: now, pick: results[j].pick);
        }
      }
    }
    _candidates = ids;
    _picks.removeWhere((id, _) => !ids.contains(id));
    _savedAt = now;
    _rebuild();
    await _writeCache();
  }

  /// Los [count] con el trailer más nuevo entre las candidatas.
  void _rebuild() {
    final picks = [for (final id in _candidates) ?_picks[id]?.pick]
      ..sort((a, b) => b.published.compareTo(a.published));
    final next = [for (final p in picks.take(count)) p.movie];
    if (listEquals(
      next.map((m) => m.youtubeTrailerKey).toList(),
      _trailers.map((m) => m.youtubeTrailerKey).toList(),
    )) {
      return;
    }
    _trailers = next;
    notifyListeners();
  }

  void _readCache() {
    final raw = _prefs.readOptionalString(_cacheKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _savedAt = DateTime.tryParse(json['savedAt']?.toString() ?? '');
      _candidates = [
        for (final id in (json['candidates'] as List? ?? const []))
          if (id is int) id,
      ];
      for (final entry in (json['picks'] as List? ?? const [])) {
        if (entry is! Map<String, dynamic> || entry['id'] is! int) continue;
        final checkedAt = DateTime.tryParse(
          entry['checkedAt']?.toString() ?? '',
        );
        if (checkedAt == null) continue;
        final movie = entry['movie'];
        final published = DateTime.tryParse(
          entry['published']?.toString() ?? '',
        );
        _picks[entry['id'] as int] = (
          checkedAt: checkedAt,
          pick: movie is Map<String, dynamic> && published != null
              ? TrailerPick(
                  movie: MovieItem.fromJson(movie),
                  published: published,
                )
              : null,
        );
      }
      _rebuild();
    } catch (e) {
      debugPrint('⚠️ [Adelantos] Caché ilegible: $e');
      _savedAt = null;
      _candidates = const [];
      _picks.clear();
    }
  }

  Future<void> _writeCache() async {
    try {
      await _prefs.saveString(
        _cacheKey,
        jsonEncode({
          'savedAt': _savedAt?.toIso8601String(),
          'candidates': _candidates,
          'picks': [
            for (final MapEntry(key: id, value: known) in _picks.entries)
              {
                'id': id,
                'checkedAt': known.checkedAt.toIso8601String(),
                if (known.pick case final pick?) ...{
                  'movie': pick.movie.toJson(),
                  'published': pick.published.toIso8601String(),
                },
              },
          ],
        }),
      );
    } catch (e) {
      debugPrint('⚠️ [Adelantos] No se pudo guardar la caché: $e');
    }
  }
}
