import 'dart:math' as math;

import 'package:moai3/models/movie_models.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Una película según TMDb, con lo necesario para ordenar estrenos.
class TmdbMovie {
  const TmdbMovie({
    required this.id,
    required this.title,
    this.originalTitle = '',
    this.releaseDate,
    this.voteAverage = 0,
    this.voteCount = 0,
    this.popularity = 0,
    this.inTheaters = false,
  });

  final int id;
  final String title;
  final String originalTitle;
  final DateTime? releaseDate;
  final double voteAverage;
  final int voteCount;
  final double popularity;

  /// Vino de "en cines ahora" (`now_playing`).
  final bool inTheaters;

  static TmdbMovie? fromJson(
    Map<String, dynamic> json, {
    bool inTheaters = false,
  }) {
    final id = (json['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return null;
    return TmdbMovie(
      id: id,
      title: json['title']?.toString() ?? '',
      originalTitle: json['original_title']?.toString() ?? '',
      releaseDate: DateTime.tryParse(json['release_date']?.toString() ?? ''),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      popularity: (json['popularity'] as num?)?.toDouble() ?? 0,
      inTheaters: inTheaters,
    );
  }

  /// La misma película vista desde otra lista: conserva si está en cines.
  TmdbMovie mergedWith(TmdbMovie other) => TmdbMovie(
    id: id,
    title: title,
    originalTitle: originalTitle,
    releaseDate: releaseDate ?? other.releaseDate,
    voteAverage: voteAverage,
    voteCount: voteCount,
    popularity: math.max(popularity, other.popularity),
    inTheaters: inTheaters || other.inTheaters,
  );
}

/// Ordena los estrenos de la fila de Películas: sólo nuevas (según TMDb, el
/// catálogo no trae año de estreno) y, entre ellas, primero las mejores.
///
/// Puntaje: calidad 45 % (promedio de TMDb ajustado por cantidad de votos,
/// lo más cercano a "aclamada"), novedad 35 %, popularidad 20 % y un plus si
/// está en cines.
class NewReleaseRanker {
  const NewReleaseRanker({
    this.maxAge = const Duration(days: 540),
    this.targetCount = 10,
  });

  /// Más vieja que esto no es "nueva" y queda afuera.
  final Duration maxAge;
  final int targetCount;

  /// Votos a partir de los cuales el promedio de TMDb pesa más que la media.
  static const double _minVotes = 150;

  /// Media con la que se ajustan los promedios de pocos votos.
  static const double _meanVote = 6.5;

  static const double _theatersBonus = 0.08;

  /// Puntaje de 0 a ~1,08 de una candidata ya cruzada; `null` si no es nueva.
  double? score(TmdbMovie movie, DateTime now, {double maxPopularity = 1}) {
    final release = movie.releaseDate;
    if (release == null) return null;
    final age = now.difference(release);
    // Unos días de margen: la fecha de TMDb puede ser la de otro país.
    if (age.isNegative && age.abs() > const Duration(days: 7)) return null;
    if (age > maxAge) return null;

    final votes = movie.voteCount.toDouble();
    final weighted =
        (votes / (votes + _minVotes)) * movie.voteAverage +
        (_minVotes / (votes + _minVotes)) * _meanVote;
    final quality = ((weighted - 5) / 3.5).clamp(0.0, 1.0);
    final recency = (1 - age.inDays / maxAge.inDays).clamp(0.0, 1.0);
    final popularity = maxPopularity <= 0
        ? 0.0
        : (math.log(1 + movie.popularity) / math.log(1 + maxPopularity)).clamp(
            0.0,
            1.0,
          );

    return 0.45 * quality +
        0.35 * recency +
        0.20 * popularity +
        (movie.inTheaters ? _theatersBonus : 0);
  }

  /// Cruza [candidates] con [catalog] por título o alias exactos
  /// (normalizados), ordena por [score] y, si no llegan a [targetCount],
  /// completa con [theatrical] (estrenos de cine del proveedor) por puntaje
  /// del catálogo. Las cruzadas llevan el año de estreno de TMDb.
  List<MovieItem> rank({
    required List<TmdbMovie> candidates,
    required List<MovieItem> catalog,
    List<MovieItem> theatrical = const [],
    required DateTime now,
  }) {
    final matched = match(candidates: candidates, catalog: catalog);
    final maxPopularity = matched.fold<double>(
      0,
      (max, m) => math.max(max, m.$1.popularity),
    );
    final scored = [
      for (final (candidate, movie) in matched)
        if (score(candidate, now, maxPopularity: maxPopularity)
            case final value?)
          (value, candidate, movie),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    final result = [
      for (final (_, candidate, movie) in scored.take(targetCount))
        movie.withYear('${candidate.releaseDate!.year}'),
    ];
    final inRow = {for (final m in result) m.contentId};

    if (result.length < targetCount) {
      final fill =
          theatrical
              .where((m) => m.isMovie && !inRow.contains(m.contentId))
              .toList()
            ..sort((a, b) => _catalogScore(b).compareTo(_catalogScore(a)));
      for (final movie in fill) {
        if (result.length >= targetCount) break;
        if (inRow.add(movie.contentId)) result.add(movie);
      }
    }
    return result;
  }

  /// Las candidatas que están en el catálogo (título o alias exactos,
  /// normalizados), cada película del catálogo una sola vez.
  List<(TmdbMovie, MovieItem)> match({
    required List<TmdbMovie> candidates,
    required List<MovieItem> catalog,
  }) {
    final byTitle = <String, MovieItem>{};
    for (final movie in catalog) {
      if (!movie.isMovie) continue;
      for (final title in [movie.name, movie.alias]) {
        final key = normalizeText(title);
        if (key.isNotEmpty) byTitle.putIfAbsent(key, () => movie);
      }
    }

    final matched = <(TmdbMovie, MovieItem)>[];
    final used = <String>{};
    for (final candidate in candidates) {
      for (final title in [candidate.title, candidate.originalTitle]) {
        final movie = byTitle[normalizeText(title)];
        if (movie != null && used.add(movie.contentId)) {
          matched.add((candidate, movie));
          break;
        }
      }
    }
    return matched;
  }

  static double _catalogScore(MovieItem movie) =>
      double.tryParse(movie.score ?? '') ?? 0;
}
