import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/tmdb_trending_service.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Películas del banner de Películas: las nuevas (de este año o del
/// anterior) con buen puntaje, la mejor primero; si no llegan a [count], se
/// completan con los Estrenos de Cartelera en su orden. Sólo películas con
/// imagen horizontal (con el póster el banner queda feo) y sin repetidas.
List<MovieItem> pickPromoMovies(
  List<CategoryColumn> categories, {
  int count = 6,
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;
  final seen = <String>{};
  final candidates = <MovieItem>[];
  for (final category in categories) {
    for (final movie in category.movies) {
      if (_fits(movie) && seen.add(normalizeText(movie.name))) {
        candidates.add(movie);
      }
    }
  }

  double scoreOf(MovieItem m) => double.tryParse(m.score?.trim() ?? '') ?? 0;
  final recent = candidates.where((m) {
    final released = int.tryParse(m.formattedYear ?? '');
    return released != null && released >= year - 1 && m.isWellRated;
  }).toList()..sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));

  final picked = recent.take(count).toList();
  if (picked.length < count) {
    final names = {for (final m in picked) normalizeText(m.name)};
    final trending = categories
        .where((c) => c.columnId == TmdbTrendingService.trendingColumnId)
        .firstOrNull;
    for (final movie in trending?.movies ?? const <MovieItem>[]) {
      if (picked.length >= count) break;
      if (_fits(movie) && names.add(normalizeText(movie.name))) {
        picked.add(movie);
      }
    }
  }
  return List.unmodifiable(picked);
}

bool _fits(MovieItem movie) =>
    movie.isMovie && movie.distinctBackdrops.isNotEmpty;

/// Series de la tarjeta grande (arriba de Series y a la derecha de la
/// destacada del Inicio): como [pickPromoMovies], sólo del catálogo. Una por
/// serie ([_bestSeasonBySeries]), con el nombre de la serie sin "T2".
/// Primero las de este año o del anterior con buen puntaje; si no llegan a
/// [count], las mejor puntuadas de cualquier año. Sólo con imagen
/// horizontal.
List<MovieItem> pickPromoSeries(
  List<CategoryColumn> categories, {
  int count = 6,
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;
  final byScore = _bestSeasonBySeries(categories, needsBackdrop: true);
  bool recent(MovieItem m) => _releasedSince(m, year - 1) && m.isWellRated;
  return _asSeries(
    [
      ...byScore.where(recent),
      ...byScore.where((m) => !recent(m) && m.isWellRated),
    ].take(count),
  );
}

/// "Lo mejor del año" de Series, debajo del banner (en Películas sale de
/// TMDb, que no tiene series): del catálogo, una por serie, las de este año
/// o del anterior con mejor puntaje y, si no llegan a [count], las mejor
/// puntuadas de cualquier año. Sin las del banner ([exclude], por nombre).
List<MovieItem> pickBestSeries(
  List<CategoryColumn> categories, {
  required int count,
  Iterable<MovieItem> exclude = const [],
  DateTime? now,
}) {
  final year = (now ?? DateTime.now()).year;
  final byScore = _bestSeasonBySeries(
    categories,
    exclude: {for (final m in exclude) normalizeText(m.name)},
  ).where((m) => _scoreOf(m) > 0);
  bool recent(MovieItem m) => _releasedSince(m, year - 1);
  return _asSeries(
    [...byScore.where(recent), ...byScore.where((m) => !recent(m))].take(count),
  );
}

double _scoreOf(MovieItem m) => double.tryParse(m.score?.trim() ?? '') ?? 0;

bool _releasedSince(MovieItem m, int year) {
  final released = int.tryParse(m.formattedYear ?? '');
  return released != null && released >= year;
}

/// Una temporada por serie (cada temporada es un ítem del catálogo): la de
/// mejor puntaje, de mayor a menor. Sin las series de [exclude] (nombres
/// normalizados, sin "T2").
List<MovieItem> _bestSeasonBySeries(
  List<CategoryColumn> categories, {
  bool needsBackdrop = false,
  Set<String> exclude = const {},
}) {
  final bySeries = <String, MovieItem>{};
  for (final category in categories) {
    for (final item in category.movies) {
      if (!item.isSeries) continue;
      if (needsBackdrop && item.distinctBackdrops.isEmpty) continue;
      final key = normalizeText(SeriesSeasonDetail.seriesTitle(item.name));
      if (exclude.contains(key)) continue;
      final known = bySeries[key];
      if (known == null || _scoreOf(item) > _scoreOf(known)) {
        bySeries[key] = item;
      }
    }
  }
  return bySeries.values.toList()
    ..sort((a, b) => _scoreOf(b).compareTo(_scoreOf(a)));
}

/// Con el nombre de la serie (sin "T2").
List<MovieItem> _asSeries(Iterable<MovieItem> items) => List.unmodifiable([
  for (final item in items)
    item.withName(SeriesSeasonDetail.seriesTitle(item.name)),
]);
