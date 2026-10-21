import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';

/// Servicio para consultar estrenos y tendencias globales de TMDb
/// y cruzarlos con el catálogo local de películas.
class TmdbTrendingService {
  static final TmdbTrendingService instance = TmdbTrendingService._internal();

  TmdbTrendingService._internal();

  List<Map<String, dynamic>>? _cachedTmdbMovies;
  DateTime? _lastFetchTime;

  /// Limpia y normaliza texto para facilitar comparaciones (sin tildes, minúsculas, sin signos)
  static String _normalize(String? text) {
    if (text == null || text.trim().isEmpty) return '';
    var clean = text.toLowerCase().trim();
    const withDia = 'áéíóúüñÁÉÍÓÚÜÑ';
    const withoutDia = 'aeiouunAEIOUUN';
    for (int i = 0; i < withDia.length; i++) {
      clean = clean.replaceAll(withDia[i], withoutDia[i]);
    }
    return clean.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Consulta tendencias y estrenos de la semana en TMDb.
  /// Guarda en caché en memoria por 4 horas para no hacer peticiones de más.
  Future<List<Map<String, dynamic>>> fetchTrendingMovies({Duration timeout = const Duration(seconds: 4)}) async {
    final now = DateTime.now();
    if (_cachedTmdbMovies != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < const Duration(hours: 4)) {
      return _cachedTmdbMovies!;
    }

    final token = kTmdbApiKey.trim();
    if (token.isEmpty) {
      debugPrint('⚠️ [TMDB] No se configuró TMDB_API_KEY en .env');
      return _cachedTmdbMovies ?? const [];
    }

    final client = HttpClient();
    final collected = <Map<String, dynamic>>[];
    final seenIds = <int>{};

    final urls = [
      'https://api.themoviedb.org/3/trending/movie/week?language=es-MX&page=1',
      'https://api.themoviedb.org/3/trending/movie/week?language=es-MX&page=2',
      'https://api.themoviedb.org/3/movie/now_playing?language=es-MX&page=1',
    ];

    for (final url in urls) {
      try {
        final isBearer = token.startsWith('ey');
        final targetUri = isBearer
            ? Uri.parse(url)
            : Uri.parse(url).replace(queryParameters: {
                ...Uri.parse(url).queryParameters,
                'api_key': token,
              });
        final request = await client.getUrl(targetUri).timeout(timeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        if (isBearer) {
          request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
        }

        final response = await request.close().timeout(timeout);
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join().timeout(timeout);
          final json = jsonDecode(body);
          if (json is Map<String, dynamic> && json['results'] is List) {
            for (final item in json['results']) {
              if (item is Map<String, dynamic>) {
                final id = item['id'] as int? ?? 0;
                if (id > 0 && seenIds.add(id)) {
                  collected.add(item);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [TMDB] Error consultando $url: $e');
      }
    }

    client.close();

    if (collected.isNotEmpty) {
      _cachedTmdbMovies = collected;
      _lastFetchTime = now;
      debugPrint('✅ [TMDB] Recibidas ${collected.length} películas en tendencia desde TMDb');
    }

    return _cachedTmdbMovies ?? const [];
  }

  /// Cruza la lista de TMDb con las películas de Moiamov y construye la fila destacada.
  /// Si faltan títulos para llegar a [targetCount] (10), completa con los estrenos
  /// teatrales y más recientes del propio catálogo.
  Future<CategoryColumn> buildTrendingRow({
    required List<MovieItem> allCatalogMovies,
    required List<CategoryColumn> existingCategories,
    int targetCount = 10,
  }) async {
    final tmdbList = await fetchTrendingMovies();
    final matchedMovies = <MovieItem>[];
    final matchedIds = <String>{};

    // 1. Emparejar con títulos de TMDb
    for (final tm in tmdbList) {
      if (matchedMovies.length >= targetCount) break;

      final tmTitle = _normalize(tm['title']?.toString());
      final tmOrig = _normalize(tm['original_title']?.toString());

      for (final lm in allCatalogMovies) {
        if (matchedIds.contains(lm.contentId)) continue;
        if (lm.isTrailer) continue; // No incluir trailers en la fila de películas

        final lmName = _normalize(lm.name);
        final lmAlias = _normalize(lm.alias);

        final isMatch = (tmTitle.isNotEmpty && (tmTitle == lmName || tmTitle == lmAlias || (tmTitle.length > 6 && lmName.contains(tmTitle)))) ||
            (tmOrig.isNotEmpty && (tmOrig == lmName || tmOrig == lmAlias || (tmOrig.length > 6 && lmAlias.contains(tmOrig))));

        if (isMatch) {
          matchedIds.add(lm.contentId);
          matchedMovies.add(lm);
          break;
        }
      }
    }

    debugPrint('🎬 [TMDB] Coincidencias directas con catálogo: ${matchedMovies.length}');

    // 2. Si faltan títulos para llegar a 10, completar con los estrenos de "2026 Peliculas teatrales"
    // o las más recientes de 2026/2025
    if (matchedMovies.length < targetCount) {
      for (final cat in existingCategories) {
        final catName = _normalize(cat.columnName);
        if (catName.contains('teatrales') || catName.contains('2026')) {
          for (final m in cat.movies) {
            if (matchedMovies.length >= targetCount) break;
            if (m.isTrailer) continue;
            if (matchedIds.add(m.contentId)) {
              matchedMovies.add(m);
            }
          }
        }
      }
    }

    // 3. Respaldo final si todavía no alcanzara 10: las más nuevas del catálogo por fecha
    if (matchedMovies.length < targetCount) {
      final sortedByDate = List<MovieItem>.from(allCatalogMovies)
        ..sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
      for (final m in sortedByDate) {
        if (matchedMovies.length >= targetCount) break;
        if (m.isTrailer) continue;
        if (matchedIds.add(m.contentId)) {
          matchedMovies.add(m);
        }
      }
    }

    return CategoryColumn(
      columnId: 88888,
      columnName: 'Estrenos de Cartelera',
      movies: matchedMovies.take(targetCount).toList(),
    );
  }
}
