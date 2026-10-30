import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';
import '../utils/text_normalize.dart';

/// Servicio para resolver metadatos de películas (como el año de estreno real)
/// consultando TMDb de forma perezosa (lazy) con caché persistente y en memoria.
class MovieMetadataService {
  static final MovieMetadataService instance = MovieMetadataService._internal();

  MovieMetadataService._internal();

  @visibleForTesting
  static void resetForTest() {
    _yearMemoryCache.clear();
    _inFlight.clear();
  }

  static final Map<String, String> _yearMemoryCache = {};

  /// Consultas en curso por `contentId`: dos pedidos seguidos de la misma
  /// película comparten una sola consulta a TMDb.
  static final Map<String, Future<String?>> _inFlight = {};

  /// Guardado cuando TMDb contestó y no hubo coincidencia. Un vacío (`''`)
  /// lo dejaba una versión anterior también ante fallos de red: se ignora y
  /// se vuelve a consultar.
  static const _noMatch = '-';

  /// Busca el año de estreno real en TMDb para una película del catálogo.
  ///
  /// 1. Si la película ya tiene un año válido en sus datos, lo devuelve.
  /// 2. Si está en la caché en memoria o en SharedPreferences, lo devuelve.
  /// 3. Si no, consulta la API `/search/movie` de TMDb en segundo plano.
  /// 4. Guarda el resultado sólo si TMDb contestó: un error de red o un
  ///    timeout no se recuerdan, la próxima vez se vuelve a intentar.
  Future<String?> resolveYear(
    MovieItem movie, {
    Duration timeout = const Duration(seconds: 4),
    HttpClient? customClient,
  }) async {
    final existing = movie.formattedYear;
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final contentId = movie.contentId.trim();
    if (contentId.isEmpty) {
      return (await _fetchYearFromTmdb(
        movie,
        timeout: timeout,
        client: customClient,
      )).year;
    }

    final cached = _yearMemoryCache[contentId];
    if (cached != null) return cached == _noMatch ? null : cached;

    return _inFlight[contentId] ??=
        _resolveAndCache(
          movie,
          contentId,
          timeout: timeout,
          client: customClient,
        ).whenComplete(() {
          // Bloque, no flecha: `remove` devuelve este mismo Future y
          // `whenComplete` lo esperaría (se esperaría a sí mismo).
          _inFlight.remove(contentId);
        });
  }

  Future<String?> _resolveAndCache(
    MovieItem movie,
    String contentId, {
    required Duration timeout,
    HttpClient? client,
  }) async {
    final key = 'tmdb_year_$contentId';
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(key);
      if (stored != null && stored.isNotEmpty) {
        _yearMemoryCache[contentId] = stored;
        return stored == _noMatch ? null : stored;
      }
    } catch (e) {
      debugPrint('⚠️ [Metadata] Error leyendo SharedPreferences: $e');
    }

    final result = await _fetchYearFromTmdb(
      movie,
      timeout: timeout,
      client: client,
    );
    if (!result.answered) return result.year;

    final value = result.year ?? _noMatch;
    _yearMemoryCache[contentId] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('⚠️ [Metadata] Error guardando año en SharedPreferences: $e');
    }
    return result.year;
  }

  /// [answered]: TMDb contestó todas las búsquedas que hicieron falta (el
  /// resultado, con o sin año, se puede guardar).
  Future<({String? year, bool answered})> _fetchYearFromTmdb(
    MovieItem movie, {
    required Duration timeout,
    HttpClient? client,
  }) async {
    // Sin clave no se pudo preguntar: no se guarda nada.
    const notAnswered = (year: null, answered: false);
    final token = kTmdbApiKey.trim();
    if (token.isEmpty) {
      return notAnswered;
    }

    // Extraer títulos limpios para la búsqueda (quitando marcas de tráiler)
    final cleanName = MovieItem.withoutTrailerTag(movie.name).trim();
    final cleanAlias = MovieItem.withoutTrailerTag(movie.alias ?? '').trim();

    final queries = <String>[];
    if (cleanName.isNotEmpty) queries.add(cleanName);
    if (cleanAlias.isNotEmpty &&
        cleanAlias.toLowerCase() != cleanName.toLowerCase()) {
      queries.add(cleanAlias);
    }

    // Sin título no hay nada que buscar: "sin año" es definitivo.
    if (queries.isEmpty) return (year: null, answered: true);

    final shouldCloseClient = client == null;
    final httpClient = client ?? HttpClient();

    try {
      for (final query in queries) {
        final results = await _searchTmdb(httpClient, query, token, timeout);

        // TMDb no contestó: no se sabe si la película tiene año.
        if (results == null) return notAnswered;
        if (results.isEmpty) continue;

        final year = _findBestMatchYear(
          candidates: results,
          targetName: cleanName,
          targetAlias: cleanAlias,
        );

        if (year != null && year.isNotEmpty) {
          debugPrint('🎬 [Metadata] Año resuelto para "${movie.name}": $year');
          return (year: year, answered: true);
        }
      }
    } catch (e) {
      debugPrint(
        '⚠️ [Metadata] Error buscando en TMDb para "${movie.name}": $e',
      );
      return notAnswered;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }

    return (year: null, answered: true);
  }

  /// Resultados de la búsqueda; `null` si TMDb no contestó (red, timeout,
  /// estado distinto de 200 o respuesta inválida).
  Future<List<Map<String, dynamic>>?> _searchTmdb(
    HttpClient client,
    String query,
    String token,
    Duration timeout,
  ) async {
    try {
      const base = 'https://api.themoviedb.org/3/search/movie';
      final isBearer = token.startsWith('ey');
      final queryParams = <String, String>{
        'query': query,
        'language': 'es-MX',
        'include_adult': 'false',
        'page': '1',
      };
      if (!isBearer) {
        queryParams['api_key'] = token;
      }

      final uri = Uri.parse(base).replace(queryParameters: queryParams);
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (isBearer) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic> || json['results'] is! List) {
        return null;
      }
      return [
        for (final item in json['results'] as List)
          if (item is Map<String, dynamic>) item,
      ];
    } catch (e) {
      debugPrint('⚠️ [Metadata] Error en _searchTmdb: $e');
      return null;
    }
  }

  String? _findBestMatchYear({
    required List<Map<String, dynamic>> candidates,
    required String targetName,
    required String targetAlias,
  }) {
    final normName = normalizeText(targetName);
    final normAlias = normalizeText(targetAlias);

    // 1. Filtrar los que coinciden exactamente en título o título original
    final exactMatches = <Map<String, dynamic>>[];
    final partialMatches = <Map<String, dynamic>>[];

    for (final item in candidates) {
      final title = normalizeText(item['title']?.toString());
      final origTitle = normalizeText(item['original_title']?.toString());

      final isExact =
          (normName.isNotEmpty &&
              (title == normName || origTitle == normName)) ||
          (normAlias.isNotEmpty &&
              (title == normAlias || origTitle == normAlias));

      if (isExact) {
        exactMatches.add(item);
      } else {
        final isPartial =
            (normName.isNotEmpty &&
                (title.startsWith(normName) || normName.startsWith(title))) ||
            (normAlias.isNotEmpty &&
                (title.startsWith(normAlias) || normAlias.startsWith(title)));
        if (isPartial) {
          partialMatches.add(item);
        }
      }
    }

    final pool = exactMatches.isNotEmpty
        ? exactMatches
        : (partialMatches.isNotEmpty ? partialMatches : candidates);

    // Ordenar por popularidad / cantidad de votos
    pool.sort((a, b) {
      final popA = (a['popularity'] as num?)?.toDouble() ?? 0.0;
      final popB = (b['popularity'] as num?)?.toDouble() ?? 0.0;
      return popB.compareTo(popA);
    });

    for (final best in pool) {
      final releaseDate = best['release_date']?.toString() ?? '';
      final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(releaseDate);
      if (match != null) {
        return match.group(0);
      }
    }

    return null;
  }
}
