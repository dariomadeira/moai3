import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Una película recomendada y quiénes la recomendaron.
class FriendRecommendation {
  const FriendRecommendation({required this.movie, required this.names});

  final MovieItem movie;
  final List<String> names;
}

/// Agrupa [rows] (la más nueva primero) por película, sin las de [hidden].
List<FriendRecommendation> groupRecommendations(
  List<Map<String, dynamic>> rows, {
  required Map<String, String> friendNames,
  required Set<String> hidden,
  int limit = 20,
}) {
  final byMovie = <String, FriendRecommendation>{};
  for (final row in rows) {
    final contentId = row['content_id'] as String? ?? '';
    final name = friendNames[row['recommender_device_id']];
    final json = row['movie'];
    if (contentId.isEmpty || name == null || hidden.contains(contentId)) {
      continue;
    }
    final known = byMovie[contentId];
    if (known != null) {
      known.names.add(name);
    } else if (json is Map<String, dynamic> && byMovie.length < limit) {
      byMovie[contentId] = FriendRecommendation(
        movie: MovieItem.fromJson(json),
        names: [name],
      );
    }
  }
  return byMovie.values.toList();
}

/// El voto de una película: sólo 👍 se comparte con los amigos.
enum MovieVote { up, down }

/// Recomendaciones entre amigos (SPEC-51). Consulta Supabase al abrir el
/// Inicio, con tope de frecuencia; lo demás (votos, borradas y envíos
/// pendientes) vive en este TV.
class MovieRecommendationsProvider extends ChangeNotifier {
  MovieRecommendationsProvider({
    MovieRecommendationsApi? api,
    Future<bool> Function(String contentId)? isWatched,
  }) : _api = api ?? MovieRecommendationsApi(),
       _isWatched = isWatched ?? _watchedInProgress;

  static const String _key = 'movie_recommendations_state';
  static const int _maxRemembered = 500;
  static const Duration _minRefreshInterval = Duration(minutes: 2);

  final MovieRecommendationsApi _api;
  final Future<bool> Function(String contentId) _isWatched;

  final Map<String, String> _votes = {};
  final Set<String> _dismissed = {};
  final Set<String> _watched = {};

  /// 👍 que todavía no llegaron a Supabase.
  final Map<String, Map<String, dynamic>> _pending = {};

  /// 👍 quitados que todavía hay que borrar de Supabase.
  final Set<String> _pendingRemovals = {};
  Future<void>? _loading;

  String _deviceId = '';
  Map<String, String> _friends = const {};
  List<Map<String, dynamic>> _rows = const [];
  List<FriendRecommendation> _items = const [];
  DateTime? _refreshedAt;

  static Future<bool> _watchedInProgress(String contentId) async =>
      (await MovieProgressService.getProgress(contentId))?.isCompleted ?? false;

  List<FriendRecommendation> get items => _items;

  /// Hay con quién compartir.
  bool get canRecommend => _deviceId.isNotEmpty && _friends.isNotEmpty;

  MovieVote? voteOf(String contentId) => switch (_votes[contentId]) {
    'up' => MovieVote.up,
    'down' => MovieVote.down,
    _ => null,
  };

  /// Todavía no se votó: el cartel del final puede preguntar.
  bool shouldAsk(String contentId) => voteOf(contentId) == null;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _votes.addAll((json['answers'] as Map).cast<String, String>());
      _dismissed.addAll((json['dismissed'] as List).cast<String>());
      _pending.addAll(
        (json['pending'] as Map).cast<String, Map<String, dynamic>>(),
      );
      _pendingRemovals.addAll(
        ((json['removals'] as List?) ?? const []).cast<String>(),
      );
    } catch (e) {
      debugPrint('[MovieRecommendations] No se pudo leer: $e');
    }
    notifyListeners();
  }

  Future<void> _save() async {
    while (_votes.length > _maxRemembered) {
      _votes.remove(_votes.keys.first);
    }
    while (_dismissed.length > _maxRemembered) {
      _dismissed.remove(_dismissed.first);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'answers': _votes,
          'dismissed': _dismissed.toList(),
          'pending': _pending,
          'removals': _pendingRemovals.toList(),
        }),
      );
    } catch (e) {
      debugPrint('[MovieRecommendations] No se pudo guardar: $e');
    }
  }

  /// Los amigos mutuos, id → nombre. Si cambian, se consulta sin esperar.
  void setFriends({
    required String deviceId,
    required Map<String, String> friends,
  }) {
    if (deviceId == _deviceId && mapEquals(friends, _friends)) return;
    final sameIds =
        deviceId == _deviceId &&
        setEquals(friends.keys.toSet(), _friends.keys.toSet());
    _deviceId = deviceId;
    _friends = friends;
    if (sameIds) {
      _rebuild();
      return;
    }
    _refreshedAt = null;
    notifyListeners();
    unawaited(refresh());
  }

  /// Al abrir el Inicio o volver de ver algo. Lo visto se revisa siempre; a
  /// la red se sale como máximo cada [_minRefreshInterval].
  Future<void> refresh() async {
    await ensureLoaded();
    await _reloadWatched();
    _rebuild();
    if (_deviceId.isEmpty) return;

    final last = _refreshedAt;
    if (last != null && DateTime.now().difference(last) < _minRefreshInterval) {
      return;
    }
    _refreshedAt = DateTime.now();

    await _flushPending();
    if (_friends.isEmpty) {
      _rows = const [];
      _rebuild();
      return;
    }
    try {
      _rows = await _api.fetch(_friends.keys.toList());
      await _reloadWatched();
      _rebuild();
    } catch (e) {
      debugPrint('[MovieRecommendations] No se pudo consultar: $e');
    }
  }

  Future<void> _reloadWatched() async {
    final ids = {for (final row in _rows) row['content_id'] as String? ?? ''};
    final watched = <String>{};
    for (final id in ids) {
      if (id.isNotEmpty && await _isWatched(id)) watched.add(id);
    }
    _watched
      ..clear()
      ..addAll(watched);
  }

  /// Lo que no se pudo mandar se reintenta en la próxima consulta.
  Future<void> _flushPending() async {
    if (_deviceId.isEmpty) return;
    try {
      for (final contentId in _pendingRemovals.toList()) {
        await _api.remove(_deviceId, contentId);
        _pendingRemovals.remove(contentId);
      }
      for (final entry in _pending.entries.toList()) {
        await _api.recommend(_deviceId, MovieItem.fromJson(entry.value));
        _pending.remove(entry.key);
      }
    } catch (e) {
      debugPrint('[MovieRecommendations] Queda pendiente: $e');
    }
    await _save();
  }

  void _rebuild() {
    _items = groupRecommendations(
      _rows,
      friendNames: _friends,
      hidden: {..._dismissed, ..._votes.keys, ..._watched},
    );
    notifyListeners();
  }

  /// Botones del detalle: apretar el voto actual lo quita.
  Future<void> toggleVote(MovieItem movie, MovieVote vote) =>
      setVote(movie, voteOf(movie.contentId) == vote ? null : vote);

  /// Sólo 👍 sale del TV: entrar en él publica y dejarlo borra.
  Future<void> setVote(MovieItem movie, MovieVote? vote) async {
    await ensureLoaded();
    final contentId = movie.contentId;
    final wasUp = voteOf(contentId) == MovieVote.up;
    final isUp = vote == MovieVote.up;
    if (vote == null) {
      _votes.remove(contentId);
    } else {
      _votes[contentId] = vote.name;
    }
    if (isUp && !wasUp) {
      _pendingRemovals.remove(contentId);
      _pending[contentId] = movie.toJson();
    } else if (wasUp && !isUp) {
      // Si nunca llegó a publicarse, no hay nada que borrar.
      if (_pending.remove(contentId) == null) {
        _pendingRemovals.add(contentId);
      }
    }
    _rebuild();
    await _save();
    await _flushPending();
  }

  /// La saca de la tarjeta de este TV; los amigos no se enteran.
  Future<void> dismiss(String contentId) async {
    await ensureLoaded();
    _dismissed.add(contentId);
    _rebuild();
    await _save();
  }

  Future<void> dismissAll() async {
    await ensureLoaded();
    _dismissed.addAll(_items.map((item) => item.movie.contentId));
    _rebuild();
    await _save();
  }
}
