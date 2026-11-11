import 'package:moai3/models/movie_models.dart';
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
