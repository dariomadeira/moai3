import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/new_release_ranker.dart';

void main() {
  final now = DateTime(2026, 11, 5);
  MovieItem movie(String name, {String? score, DateTime? addedAt}) =>
      MovieItem(contentId: name, name: name, score: score, addedAt: addedAt);

  test('del último año, por promedio ajustado por votos', () {
    final picked = const AcclaimedRanker(count: 3).rank(
      candidates: [
        TmdbMovie(
          id: 1,
          title: 'Pocos votos',
          releaseDate: DateTime(2026, 6, 2),
          voteAverage: 10,
          voteCount: 3,
        ),
        TmdbMovie(
          id: 2,
          title: 'Aclamada',
          releaseDate: DateTime(2026, 3, 2),
          voteAverage: 8.2,
          voteCount: 5000,
        ),
        TmdbMovie(
          id: 3,
          title: 'Vieja',
          releaseDate: DateTime(2023, 3, 2),
          voteAverage: 9,
          voteCount: 9000,
        ),
        TmdbMovie(
          id: 4,
          title: 'Buena',
          releaseDate: DateTime(2026, 9, 2),
          voteAverage: 7.4,
          voteCount: 2000,
        ),
      ],
      catalog: [
        movie('Pocos votos'),
        movie('Aclamada'),
        movie('Vieja'),
        movie('Buena'),
      ],
      now: now,
    );
    expect(picked.map((m) => m.name), ['Aclamada', 'Buena', 'Pocos votos']);
    expect(picked.first.formattedYear, '2026');
  });

  test('sin TMDb: mejor puntaje entre las agregadas hace poco', () {
    final picked = const AcclaimedRanker(count: 2).rank(
      candidates: const [],
      catalog: [
        movie('Clásica', score: '9.5', addedAt: DateTime(2024, 7, 2)),
        movie('Nueva floja', score: '6.0', addedAt: DateTime(2026, 10, 20)),
        movie('Nueva buena', score: '8.4', addedAt: DateTime(2026, 10, 2)),
        movie('Sin puntaje', addedAt: DateTime(2026, 11, 2)),
      ],
      now: now,
    );
    expect(picked.map((m) => m.name), ['Nueva buena', 'Nueva floja']);
  });

  test('shelveTime del catálogo llega a addedAt', () {
    final parsed = MovieItem.fromJson({
      'contentId': 'x',
      'name': 'X',
      'shelveTime': '2026-11-02 07:13:57',
    });
    expect(parsed.addedAt, DateTime(2026, 11, 2, 7, 13, 57));
    expect(MovieItem.fromJson(parsed.toJson()).addedAt, parsed.addedAt);
  });
}
