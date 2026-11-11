import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/movie_promo.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/tmdb_trending_service.dart';

MovieItem _movie(
  String name, {
  String? year,
  String? score,
  bool backdrop = true,
  String? programType,
}) => MovieItem(
  contentId: name,
  name: name,
  poster: 'https://example.com/$name.jpg',
  backdrop: backdrop ? 'https://example.com/$name-h.jpg' : null,
  year: year,
  score: score,
  programType: programType,
);

void main() {
  final now = DateTime(2026, 11, 5);

  test('las nuevas con buen puntaje, la mejor primero', () {
    final picked = pickPromoMovies([
      CategoryColumn(
        columnId: 1,
        columnName: 'Acción',
        movies: [
          _movie('Vieja', year: '2019', score: '9.0'),
          _movie('Nueva floja', year: '2026', score: '6.0'),
          _movie('Del año pasado', year: '2025', score: '7.5'),
          _movie('De este año', year: '2026', score: '8.2'),
          _movie('Sin foto', year: '2026', score: '9.5', backdrop: false),
          _movie('Serie', year: '2026', score: '9.1', programType: 'teleplay'),
        ],
      ),
    ], now: now);
    expect(picked.map((m) => m.name), ['De este año', 'Del año pasado']);
  });

  test('completa con Estrenos de Cartelera, sin repetir', () {
    final picked = pickPromoMovies(
      [
        CategoryColumn(
          columnId: TmdbTrendingService.trendingColumnId,
          columnName: 'Estrenos de Cartelera',
          movies: [
            _movie('Estreno A'),
            _movie('Nueva', year: '2026', score: '8.0'),
            _movie('Estreno B'),
            _movie('Estreno C'),
          ],
        ),
        CategoryColumn(
          columnId: 2,
          columnName: 'Drama',
          movies: [_movie('nueva', year: '2026', score: '8.0')],
        ),
      ],
      count: 3,
      now: now,
    );
    expect(picked.map((m) => m.name), ['Nueva', 'Estreno A', 'Estreno B']);
  });

  test('sin candidatas no hay banner', () {
    expect(pickPromoMovies(const [], now: now), isEmpty);
  });
}
