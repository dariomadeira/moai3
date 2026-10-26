import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/new_release_ranker.dart';

void main() {
  final now = DateTime(2026, 10, 25);
  const ranker = NewReleaseRanker();

  TmdbMovie tmdb(
    String title, {
    required int daysAgo,
    double vote = 7,
    int votes = 1000,
    double popularity = 50,
    bool inTheaters = false,
    String originalTitle = '',
  }) => TmdbMovie(
    id: title.hashCode,
    title: title,
    originalTitle: originalTitle,
    releaseDate: now.subtract(Duration(days: daysAgo)),
    voteAverage: vote,
    voteCount: votes,
    popularity: popularity,
    inTheaters: inTheaters,
  );

  MovieItem movie(String name, {String? alias, String? score, String? year}) =>
      MovieItem(
        contentId: name,
        name: name,
        alias: alias,
        score: score,
        year: year ?? '2026',
        programType: 'movie',
      );

  List<String> names(List<MovieItem> movies) =>
      movies.map((m) => m.name).toList();

  test('deja afuera lo que no es nuevo, aunque el catálogo diga 2026', () {
    final result = ranker.rank(
      candidates: [
        tmdb('Rocky', daysAgo: 365 * 50, vote: 8.1),
        tmdb('Tenzing', daysAgo: 30),
      ],
      catalog: [movie('Rocky'), movie('Tenzing')],
      now: now,
    );
    expect(names(result), ['Tenzing']);
  });

  test('entre nuevas, la mejor puntuada y con votos va primero', () {
    final result = ranker.rank(
      candidates: [
        tmdb('Floja', daysAgo: 20, vote: 5.5),
        tmdb('Aclamada', daysAgo: 60, vote: 8.4, votes: 4000),
        // Buen promedio pero con muy pocos votos: pesa poco.
        tmdb('Pocos votos', daysAgo: 20, vote: 9.5, votes: 5),
      ],
      catalog: [movie('Floja'), movie('Aclamada'), movie('Pocos votos')],
      now: now,
    );
    expect(result.first.name, 'Aclamada');
    expect(result.last.name, 'Floja');
  });

  test('a igual calidad, la más reciente va primero', () {
    final result = ranker.rank(
      candidates: [
        tmdb('De hace un año', daysAgo: 365),
        tmdb('De este mes', daysAgo: 10),
      ],
      catalog: [movie('De hace un año'), movie('De este mes')],
      now: now,
    );
    expect(names(result), ['De este mes', 'De hace un año']);
  });

  test('estar en cines suma', () {
    final result = ranker.rank(
      candidates: [
        tmdb('En casa', daysAgo: 30),
        tmdb('En cines', daysAgo: 30, inTheaters: true),
      ],
      catalog: [movie('En casa'), movie('En cines')],
      now: now,
    );
    expect(result.first.name, 'En cines');
  });

  test('cruza por título o alias exactos, no por "contiene"', () {
    final result = ranker.rank(
      candidates: [
        tmdb('Superman', daysAgo: 30),
        tmdb('Chainsaw Man', daysAgo: 30, originalTitle: 'Chainsaw Man Reze'),
      ],
      catalog: [
        movie('Superman y Lois'),
        movie('Chainsaw Man: El arco de Reze', alias: 'Chainsaw Man Reze'),
      ],
      now: now,
    );
    expect(names(result), ['Chainsaw Man: El arco de Reze']);
  });

  test('las cruzadas llevan el año de estreno de TMDb', () {
    final result = ranker.rank(
      candidates: [tmdb('Avatar 3', daysAgo: 300)],
      catalog: [movie('Avatar 3', year: '2026')],
      now: now,
    );
    expect(result.single.year, '2025');
  });

  test('completa con estrenos de cine por puntaje, sin repetir', () {
    final result = ranker.rank(
      candidates: [tmdb('Tenzing', daysAgo: 30)],
      catalog: [movie('Tenzing')],
      theatrical: [
        movie('Tenzing', score: '9'),
        movie('Floja', score: '5.1'),
        movie('Buena', score: '7.9'),
      ],
      now: now,
    );
    expect(names(result), ['Tenzing', 'Buena', 'Floja']);
  });

  test('no pasa de 10 ni incluye series o tráileres', () {
    final candidates = [
      for (var i = 0; i < 15; i++) tmdb('Peli $i', daysAgo: 10 + i),
      tmdb('Serie S1', daysAgo: 5),
    ];
    final result = ranker.rank(
      candidates: candidates,
      catalog: [
        for (var i = 0; i < 15; i++) movie('Peli $i'),
        movie('Serie S1'),
      ],
      now: now,
    );
    expect(result, hasLength(10));
    expect(names(result), isNot(contains('Serie S1')));
  });

  test('sin fecha de estreno no entra', () {
    final result = ranker.rank(
      candidates: [const TmdbMovie(id: 1, title: 'Sin fecha')],
      catalog: [movie('Sin fecha')],
      now: now,
    );
    expect(result, isEmpty);
  });
}
