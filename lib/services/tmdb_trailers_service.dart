import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/models/movie_models.dart';

/// Pide un JSON a TMDb: [path] relativo a `/3` y su [query]. `null` si no
/// contestó bien.
typedef TmdbJsonFetcher =
    Future<Map<String, dynamic>?> Function(
      String path,
      Map<String, String> query,
    );

/// Adelanto elegido para una película: la película (con el video) y cuándo
/// se publicó el video en YouTube.
class TrailerPick {
  const TrailerPick({required this.movie, required this.published});

  final MovieItem movie;
  final DateTime published;
}

/// Adelantos del Inicio desde TMDb, sin el catálogo del portal: las
/// películas en cartelera y por estrenarse y el trailer de YouTube de cada
/// una (en castellano si hay). Cada película es un solo pedido (detalle y
/// videos juntos).
class TmdbTrailersService {
  /// [fetchJson] se reemplaza en los tests.
  TmdbTrailersService({TmdbJsonFetcher? fetchJson})
    : _fetchJson = fetchJson ?? _httpFetch;

  final TmdbJsonFetcher _fetchJson;

  static const String _language = 'es-MX';

  /// Películas candidatas como mucho (cartelera + próximos estrenos).
  static const int maxCandidates = 30;

  static const String _image = 'https://image.tmdb.org/t/p';

  /// Las películas en cartelera y por estrenarse (ids de TMDb, sin
  /// repetidas, las de cartelera primero). `null` si TMDb no contestó.
  Future<List<int>?> candidateIds() async {
    final pages = await Future.wait([
      _fetchJson('/movie/now_playing', const {'language': _language}),
      _fetchJson('/movie/upcoming', const {'language': _language}),
    ]);
    if (pages.every((p) => p == null)) return null;
    final ids = <int>{};
    for (final page in pages) {
      final results = page?['results'];
      if (results is! List) continue;
      for (final item in results) {
        if (item is Map && item['id'] is int) ids.add(item['id'] as int);
      }
    }
    return ids.take(maxCandidates).toList();
  }

  /// El adelanto de la película [tmdbId]. `(answered: true, pick: null)` si
  /// TMDb contestó pero no tiene trailer de YouTube; `answered: false` si no
  /// contestó (se reintenta más adelante).
  Future<({bool answered, TrailerPick? pick})> pickFor(int tmdbId) async {
    final json = await _fetchJson('/movie/$tmdbId', const {
      'language': _language,
      'append_to_response': 'videos',
      'include_video_language': 'es,en',
    });
    if (json == null) return (answered: false, pick: null);
    return (answered: true, pick: parsePick(json));
  }

  /// Arma el adelanto con el detalle de TMDb (`append_to_response=videos`).
  /// `null` sin trailer de YouTube.
  @visibleForTesting
  static TrailerPick? parsePick(Map<String, dynamic> json) {
    final id = json['id'];
    final title = (json['title'] ?? json['original_title'])?.toString().trim();
    final videos = (json['videos'] as Map?)?['results'];
    if (id is! int || title == null || title.isEmpty || videos is! List) {
      return null;
    }
    final video = _bestVideo(videos.whereType<Map>());
    if (video == null) return null;

    final key = video['key'].toString();
    String? image(Object? path, String size) =>
        path is String && path.isNotEmpty ? '$_image/$size$path' : null;
    final vote = json['vote_average'];
    final genres = [
      for (final g in (json['genres'] as List?) ?? const [])
        if (g is Map && g['name'] is String) g['name'] as String,
    ];
    final overview = json['overview']?.toString().trim();
    final release = json['release_date']?.toString() ?? '';

    return TrailerPick(
      published:
          DateTime.tryParse(video['published_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      movie: MovieItem(
        contentId: 'tmdb_$id',
        name: title,
        alias: json['original_title']?.toString(),
        poster: image(json['poster_path'], 'w500'),
        // Sin fondo en TMDb, la miniatura del video (siempre existe).
        backdrop:
            image(json['backdrop_path'], 'w1280') ??
            'https://i.ytimg.com/vi/$key/hqdefault.jpg',
        score: vote is num && vote > 0 ? vote.toStringAsFixed(1) : null,
        year: release.length >= 4 ? release.substring(0, 4) : null,
        description: overview == null || overview.isEmpty ? null : overview,
        tags: genres.isEmpty ? null : genres.join(', '),
        youtubeTrailerKey: key,
      ),
    );
  }

  /// El trailer (o, si no hay, el teaser) de YouTube: en castellano antes
  /// que en inglés, el oficial antes y, entre iguales, el más nuevo.
  static Map? _bestVideo(Iterable<Map> videos) {
    final youtube = [
      for (final v in videos)
        if (v['site'] == 'YouTube' &&
            v['key'] is String &&
            (v['key'] as String).isNotEmpty)
          v,
    ];
    for (final type in const ['Trailer', 'Teaser']) {
      final ofType = youtube.where((v) => v['type'] == type).toList();
      if (ofType.isEmpty) continue;
      int rank(Map v) =>
          (v['iso_639_1'] == 'es' ? 2 : 0) + (v['official'] == true ? 1 : 0);
      ofType.sort((a, b) {
        final byRank = rank(b).compareTo(rank(a));
        if (byRank != 0) return byRank;
        return (b['published_at']?.toString() ?? '').compareTo(
          a['published_at']?.toString() ?? '',
        );
      });
      return ofType.first;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _httpFetch(
    String path,
    Map<String, String> query,
  ) async {
    final token = kTmdbApiKey.trim();
    if (token.isEmpty) return null;
    // Como en TmdbTrendingService: token de lectura (Bearer) o api_key.
    final isBearer = token.startsWith('ey');
    final uri = Uri.https('api.themoviedb.org', '/3$path', {
      ...query,
      if (!isBearer) 'api_key': token,
    });
    try {
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (isBearer) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      final json = jsonDecode(body);
      return json is Map<String, dynamic> ? json : null;
    } catch (e) {
      debugPrint('⚠️ [TMDB] Adelantos ($path): $e');
      return null;
    }
  }

  static const Duration _timeout = Duration(seconds: 6);

  /// Uno solo para todos los pedidos: reutiliza la conexión con TMDb.
  static final HttpClient _client = HttpClient()..connectionTimeout = _timeout;
}
