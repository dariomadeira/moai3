import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';
import 'package:moai3/services/new_release_ranker.dart';
import 'package:moai3/utils/text_normalize.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Servicio para consultar estrenos y tendencias globales de TMDb
/// y cruzarlos con el catálogo local de películas.
class TmdbTrendingService {
  static final TmdbTrendingService instance = TmdbTrendingService._internal();

  /// `columnId` de la fila "Estrenos de Cartelera" (local, no del servidor).
  static const int trendingColumnId = 88888;

  TmdbTrendingService._internal();

  static const _ranker = NewReleaseRanker();

  static const _acclaimedRanker = AcclaimedRanker();

  List<TmdbMovie>? _cachedTmdbMovies;
  DateTime? _lastFetchTime;

  /// El pedido en curso: al arrancar lo piden a la vez los estrenos y "Lo
  /// mejor del año"; el segundo espera al primero en vez de repetir los
  /// pedidos a TMDb.
  Future<List<TmdbMovie>>? _trendingInFlight;

  List<TmdbMovie>? _cachedAcclaimed;
  DateTime? _lastAcclaimedFetch;

  /// Candidatas a estreno: tendencias de la semana, en cines ahora y lo
  /// estrenado en el último año y medio con votos suficientes. Las consultas
  /// van en paralelo. Guarda en caché en memoria por 4 horas.
  Future<List<TmdbMovie>> fetchTrendingMovies({
    Duration timeout = const Duration(seconds: 4),
  }) {
    final inFlight = _trendingInFlight;
    if (inFlight != null) return inFlight;
    final request = _fetchTrendingMovies(timeout);
    _trendingInFlight = request;
    return request.whenComplete(() => _trendingInFlight = null);
  }

  Future<List<TmdbMovie>> _fetchTrendingMovies(Duration timeout) async {
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

    final since = now.subtract(_ranker.maxAge);
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    const base = 'https://api.themoviedb.org/3';
    final discover =
        '$base/discover/movie?language=es-MX&sort_by=popularity.desc'
        '&include_adult=false&vote_count.gte=50'
        '&primary_release_date.gte=${day(since)}&primary_release_date.lte=${day(now)}';
    final urls = <(String, bool)>[
      ('$base/movie/now_playing?language=es-MX&page=1', true),
      ('$base/movie/now_playing?language=es-MX&page=2', true),
      ('$base/trending/movie/week?language=es-MX&page=1', false),
      ('$base/trending/movie/week?language=es-MX&page=2', false),
      for (var page = 1; page <= 5; page++) ('$discover&page=$page', false),
    ];

    final client = HttpClient();
    final pages = await Future.wait([
      for (final (url, inTheaters) in urls)
        _fetchPage(client, url, token, timeout, inTheaters: inTheaters),
    ]);
    client.close();

    final byId = <int, TmdbMovie>{};
    for (final movie in pages.expand((p) => p)) {
      byId.update(movie.id, (seen) => seen.mergedWith(movie), ifAbsent: () => movie);
    }

    if (byId.isNotEmpty) {
      _cachedTmdbMovies = byId.values.toList();
      _lastFetchTime = now;
      debugPrint('✅ [TMDB] Recibidas ${byId.length} películas candidatas a estreno desde TMDb');
    }

    return _cachedTmdbMovies ?? const [];
  }

  Future<List<TmdbMovie>> _fetchPage(
    HttpClient client,
    String url,
    String token,
    Duration timeout, {
    required bool inTheaters,
  }) async {
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
      if (response.statusCode != 200) return const [];
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic> || json['results'] is! List) return const [];
      return [
        for (final item in json['results'] as List)
          if (item is Map<String, dynamic>)
            ?TmdbMovie.fromJson(item, inTheaters: inTheaters),
      ];
    } catch (e) {
      debugPrint('⚠️ [TMDB] Error consultando $url: $e');
      return const [];
    }
  }

  /// Las mejor votadas por el público de lo estrenado en el último año.
  /// Caché en memoria de 4 horas, como las candidatas a estreno.
  Future<List<TmdbMovie>> fetchAcclaimedMovies({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final now = DateTime.now();
    if (_cachedAcclaimed != null &&
        _lastAcclaimedFetch != null &&
        now.difference(_lastAcclaimedFetch!) < const Duration(hours: 4)) {
      return _cachedAcclaimed!;
    }
    final token = kTmdbApiKey.trim();
    if (token.isEmpty) return _cachedAcclaimed ?? const [];

    final since = now.subtract(_acclaimedRanker.maxAge);
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    const discover =
        'https://api.themoviedb.org/3/discover/movie?language=es-MX'
        '&sort_by=vote_average.desc&include_adult=false&vote_count.gte=300';
    final range =
        '&primary_release_date.gte=${day(since)}&primary_release_date.lte=${day(now)}';

    final client = HttpClient();
    final pages = await Future.wait([
      for (var page = 1; page <= 3; page++)
        _fetchPage(
          client,
          '$discover$range&page=$page',
          token,
          timeout,
          inTheaters: false,
        ),
    ]);
    client.close();

    final movies = pages.expand((p) => p).toList();
    if (movies.isNotEmpty) {
      _cachedAcclaimed = movies;
      _lastAcclaimedFetch = now;
    }
    return _cachedAcclaimed ?? const [];
  }

  /// "Lo mejor del año" de Películas ([AcclaimedRanker]): espera a TMDb
  /// como mucho [wait]; sin respuesta, sale sólo con el respaldo local.
  Future<List<MovieItem>> buildBestOfYear({
    required List<MovieItem> allCatalogMovies,
    required Duration wait,
  }) async {
    var candidates = const <TmdbMovie>[];
    try {
      final lists = await Future.wait([
        fetchAcclaimedMovies(),
        fetchTrendingMovies(),
      ]).timeout(wait);
      final byId = <int, TmdbMovie>{
        for (final movie in lists.expand((l) => l)) movie.id: movie,
      };
      candidates = byId.values.toList();
    } catch (e) {
      debugPrint('⚠️ [TMDB] Sin "lo mejor del año" de TMDb: $e');
    }
    final movies = _acclaimedRanker.rank(
      candidates: candidates,
      catalog: allCatalogMovies,
      now: DateTime.now(),
    );
    debugPrint(
      '🏆 [TMDB] Lo mejor del año (${movies.length}): '
      '${movies.map((m) => m.name).join(' · ')}',
    );
    return movies;
  }

  /// Arma la fila "Estrenos de cartelera" de Películas: las candidatas de
  /// TMDb que están en el catálogo, sólo nuevas y ordenadas por
  /// [NewReleaseRanker]. Si no llegan a 10 completa con la categoría de
  /// estrenos de cine del proveedor ("… teatrales"); nunca con títulos
  /// viejos (el año del catálogo es de cuándo se subió, no del estreno).
  Future<CategoryColumn> buildTrendingRow({
    required List<MovieItem> allCatalogMovies,
    required List<CategoryColumn> existingCategories,
  }) async {
    final candidates = await fetchTrendingMovies();
    final now = DateTime.now();
    final theatrical = [
      for (final cat in existingCategories)
        if (normalizeText(cat.columnName).contains('teatrales')) ...cat.movies,
    ];
    final movies = _ranker.rank(
      candidates: candidates,
      catalog: allCatalogMovies,
      theatrical: theatrical,
      now: now,
    );

    final matched =_ranker.match(candidates: candidates, catalog: allCatalogMovies);
    final fresh = matched.where((m) => _ranker.score(m.$1, now) != null).length;
    debugPrint(
      '🎬 [TMDB] En el catálogo: ${matched.length} de ${candidates.length} '
      '(nuevas: $fresh); el resto de la fila es relleno de estrenos de cine',
    );
    debugPrint(
      '🎬 [TMDB] Estrenos en la fila (${movies.length}): '
      '${movies.map((m) => '${m.name} (${m.year})').join(' · ')}',
    );

    return CategoryColumn(
      columnId: trendingColumnId,
      columnName: LocaleKeys.movies_category_new_releases.tr(),
      movies: movies,
    );
  }
}
