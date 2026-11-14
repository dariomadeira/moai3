import 'package:flutter/foundation.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/tmdb_trailers_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La sinopsis en español de TMDb para los títulos que el catálogo trae sin
/// sinopsis o en inglés. Se busca por el id de IMDb (el portal lo manda en
/// `keyWords` del detalle), que da el título exacto sin adivinar por nombre.
///
/// Sólo trabaja al abrir un detalle que lo necesita ([needsLookup]) y guarda
/// lo que encuentra: cada título se consulta una vez.
class MovieSynopsisService {
  /// [fetchJson] y [fetchImdbId] se reemplazan en los tests.
  MovieSynopsisService({
    TmdbJsonFetcher? fetchJson,
    Future<String?> Function(String contentId)? fetchImdbId,
  }) : _fetchJson = fetchJson ?? TmdbTrailersService.httpFetch,
       _fetchImdbId =
           fetchImdbId ?? MoiamovApiService.instance.fetchMovieImdbId;

  static final MovieSynopsisService instance = MovieSynopsisService();

  final TmdbJsonFetcher _fetchJson;
  final Future<String?> Function(String contentId) _fetchImdbId;

  /// Idiomas en que se pide, en orden: latino y, si TMDb no lo tiene, de
  /// España (muchas películas españolas y europeas sólo están ahí).
  static const List<String> _spanish = ['es-MX', 'es-ES'];
  static const String _english = 'en-US';

  /// Guardado cuando TMDb contestó y no tiene sinopsis.
  static const String _none = '-';

  final Map<String, String> _memory = {};
  final Map<String, Future<String?>> _inFlight = {};

  static final RegExp _englishWords = RegExp(
    r'\b(the|and|with|his|her|their|who|when|after|from|into|is|of|to)\b',
    caseSensitive: false,
  );
  static final RegExp _spanishWords = RegExp(
    r'\b(el|la|los|las|una|un|que|con|del|por|para|su|se|en|de|y)\b',
    caseSensitive: false,
  );

  /// Textos que el portal pone cuando no tiene sinopsis.
  static final RegExp _placeholder = RegExp(
    r'^(sem dados de descri[cç][aã]o|no description|sin descripci[oó]n|n/?a)\.?$',
    caseSensitive: false,
  );

  /// La sinopsis del catálogo no sirve: falta, es un relleno o está en
  /// inglés (más palabras comunes del inglés que del español).
  static bool needsLookup(String? description) {
    final text = (description ?? '').trim();
    if (text.isEmpty || _placeholder.hasMatch(text)) return true;
    final english = _englishWords.allMatches(text).length;
    return english >= 2 && english > _spanishWords.allMatches(text).length;
  }

  /// No hay nada que mostrar (ni siquiera en inglés).
  static bool isMissing(String? description) {
    final text = (description ?? '').trim();
    return text.isEmpty || _placeholder.hasMatch(text);
  }

  /// La sinopsis de TMDb para una película del catálogo, si la suya no
  /// sirve; `null` si no hace falta, no se consiguió o no hay.
  Future<String?> forMovie(MovieItem movie) async {
    if (!needsLookup(movie.description)) return null;
    final contentId = movie.contentId.trim();
    if (contentId.isEmpty) return null;
    final imdbId = await _imdbIdOf(contentId);
    if (imdbId == null) return null;
    return byImdbId(imdbId, allowEnglish: isMissing(movie.description));
  }

  /// La sinopsis en español del título [imdbId] ("tt1601913"), película o
  /// serie. Con [allowEnglish] (el catálogo no trae ninguna), la de inglés
  /// si no hay en español. `null` si TMDb no contestó o no tiene.
  Future<String?> byImdbId(String imdbId, {bool allowEnglish = false}) {
    final key = 'tmdb_synopsis_${allowEnglish ? 'any' : 'es'}_$imdbId';
    final known = _memory[key];
    if (known != null) return Future.value(known == _none ? null : known);
    return _inFlight[key] ??= _resolve(imdbId, key, allowEnglish).whenComplete(
      () {
        _inFlight.remove(key);
      },
    );
  }

  Future<String?> _resolve(String imdbId, String key, bool allowEnglish) async {
    final stored = await _read(key);
    if (stored != null) {
      _memory[key] = stored;
      return stored == _none ? null : stored;
    }
    for (final language in [..._spanish, if (allowEnglish) _english]) {
      final Map<String, dynamic>? found;
      try {
        found = await _fetchJson('/find/$imdbId', {
          'external_source': 'imdb_id',
          'language': language,
        });
      } catch (e) {
        debugPrint('⚠️ [Sinopsis] $imdbId: $e');
        return null;
      }
      // TMDb no contestó: no se guarda, la próxima se vuelve a intentar.
      if (found == null) return null;
      final overview = _overviewOf(found);
      if (overview != null) {
        await _save(key, overview);
        return overview;
      }
    }
    await _save(key, _none);
    return null;
  }

  static String? _overviewOf(Map<String, dynamic> found) {
    for (final list in [found['movie_results'], found['tv_results']]) {
      if (list is! List) continue;
      for (final item in list) {
        if (item is! Map) continue;
        final overview = '${item['overview'] ?? ''}'.trim();
        if (overview.isNotEmpty) return overview;
      }
    }
    return null;
  }

  /// El id de IMDb de una película: guardado o, si no, del portal.
  Future<String?> _imdbIdOf(String contentId) async {
    final key = 'imdb_of_$contentId';
    final known = _memory[key] ?? await _read(key);
    if (known != null) return known;
    String? imdbId;
    try {
      imdbId = await _fetchImdbId(contentId);
    } catch (e) {
      debugPrint('⚠️ [Sinopsis] id de IMDb de $contentId: $e');
    }
    if (imdbId == null || imdbId.isEmpty) return null;
    await _save(key, imdbId);
    return imdbId;
  }

  Future<String?> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(key);
      return value == null || value.isEmpty ? null : value;
    } catch (e) {
      debugPrint('⚠️ [Sinopsis] No se pudo leer $key: $e');
      return null;
    }
  }

  Future<void> _save(String key, String value) async {
    _memory[key] = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('⚠️ [Sinopsis] No se pudo guardar $key: $e');
    }
  }
}
