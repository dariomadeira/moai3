import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/models/torrent_stream.dart';

/// Servicio para consultar el catálogo de películas (TMDB / Cinemeta) y
/// obtener las fuentes de transmisión P2P con scoring de audio latino (SPEC-38).
class MovieService {
  static const String cinemetaPopularEndpoint =
      'https://v3-cinemeta.strem.io/catalog/movie/top.json';

  static const String tmdbPopularEndpoint =
      'https://api.themoviedb.org/3/movie/popular?language=es-MX&page=1';

  static String torrentioEndpoint(String imdbId) =>
      'https://torrentio.strem.fun/stream/movie/$imdbId.json';

  /// Obtiene el catálogo de películas populares.
  /// Intenta primero con TMDB (si se provee [tmdbApiKey]) y realiza fallback automático a Cinemeta.
  static Future<List<Movie>> fetchPopularMovies({
    String? tmdbApiKey,
    Future<String> Function(String url)? customFetcher,
  }) async {
    // 1. Intentar TMDB si existe API Key
    if (tmdbApiKey != null && tmdbApiKey.isNotEmpty) {
      try {
        final url = '$tmdbPopularEndpoint&api_key=$tmdbApiKey';
        final body = customFetcher != null
            ? await customFetcher(url)
            : await _httpGet(url);

        final data = json.decode(body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];

        if (results.isNotEmpty) {
          return results
              .whereType<Map<String, dynamic>>()
              .map((j) => Movie.fromTmdbJson(j))
              .toList();
        }
      } catch (e) {
        debugPrint('[MovieService] Error en TMDB, ejecutando fallback a Cinemeta: $e');
      }
    }

    // 2. Fallback Automático: Cinemeta Stremio (público sin API Key)
    try {
      final body = customFetcher != null
          ? await customFetcher(cinemetaPopularEndpoint)
          : await _httpGet(cinemetaPopularEndpoint);

      return parseCinemetaMovies(body);
    } catch (e) {
      debugPrint('[MovieService] Error al consultar catálogo Cinemeta: $e');
      return [];
    }
  }

  /// Parsea la respuesta JSON de Cinemeta Stremio.
  static List<Movie> parseCinemetaMovies(String jsonBody) {
    try {
      final data = json.decode(jsonBody) as Map<String, dynamic>;
      final metas = data['metas'] as List<dynamic>? ?? [];

      return metas
          .whereType<Map<String, dynamic>>()
          .map((j) => Movie.fromCinemetaJson(j))
          .toList();
    } catch (e) {
      debugPrint('[MovieService] Error al parsear JSON de Cinemeta: $e');
      return [];
    }
  }

  /// Obtiene e indexa las fuentes de transmisión Torrentio para una película dada por su [imdbId].
  /// Devuelve la lista ordenada descendentemente por [score] (audio latino primero, calidad y semillas).
  static Future<List<TorrentStream>> fetchStreamsForMovie(
    String imdbId, {
    Future<String> Function(String url)? customFetcher,
  }) async {
    if (imdbId.isEmpty) return [];

    try {
      final url = torrentioEndpoint(imdbId);
      final body = customFetcher != null ? await customFetcher(url) : await _httpGet(url);

      return parseTorrentioStreams(body);
    } catch (e) {
      debugPrint('[MovieService] Error al obtener streams de Torrentio ($imdbId): $e');
      return [];
    }
  }

  /// Parsea la respuesta JSON de Torrentio y la ordena por puntuación.
  static List<TorrentStream> parseTorrentioStreams(String jsonBody) {
    try {
      final data = json.decode(jsonBody) as Map<String, dynamic>;
      final streamsJson = data['streams'] as List<dynamic>? ?? [];

      final streams = streamsJson
          .whereType<Map<String, dynamic>>()
          .map((j) => TorrentStream.fromTorrentioJson(j))
          .toList();

      // Ordenar por score descendente (mayor puntaje de audio latino + semillas primero)
      streams.sort((a, b) => b.score.compareTo(a.score));

      return streams;
    } catch (e) {
      debugPrint('[MovieService] Error al parsear fuentes de Torrentio: $e');
      return [];
    }
  }

  /// Petición HTTP GET reutilizable con timeout de 8 segundos.
  static Future<String> _httpGet(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Mozilla/5.0 (SmartTV; MoAI 3)');
    request.headers.set('Accept', 'application/json');

    final response = await request.close();
    if (response.statusCode == 200) {
      return await response.transform(utf8.decoder).join();
    } else {
      throw HttpException('HTTP Error ${response.statusCode}', uri: Uri.parse(url));
    }
  }
}
