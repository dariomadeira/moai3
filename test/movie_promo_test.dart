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

  group('series', () {
    MovieItem season(
      String id,
      String name, {
      String? score,
      String? year,
      bool image = true,
    }) => MovieItem(
      contentId: id,
      name: name,
      programType: 'teleplay',
      score: score,
      year: year,
      backdrop: image ? 'https://img/$id.jpg' : null,
    );

    test('una por serie, con el nombre sin la temporada', () {
      final picked = pickPromoSeries([
        CategoryColumn(
          columnId: 1,
          columnName: 'Drama',
          movies: [
            season('d1', 'Dark T1', score: '8.1', year: '2017'),
            season('d3', 'Dark T3', score: '8.6', year: '2020'),
            season('b1', 'Bridgerton T1', score: '7.2', year: '2020'),
          ],
        ),
      ], now: now);
      expect([for (final s in picked) s.name], ['Dark', 'Bridgerton']);
      // De Dark queda la temporada mejor puntuada.
      expect(picked.first.contentId, 'd3');
    });

    test(
      'primero las recientes con buen puntaje; sin película ni foto, no',
      () {
        final picked = pickPromoSeries([
          CategoryColumn(
            columnId: 1,
            columnName: 'Todo',
            movies: [
              season('v', 'Vieja T1', score: '9.5', year: '2001'),
              season('n', 'Nueva T1', score: '7.5', year: '${now.year}'),
              season('f', 'Sin foto T1', score: '9.9', image: false),
              season('m', 'Mala T1', score: '5.0', year: '${now.year}'),
              _movie('p', score: '9.9'),
            ],
          ),
        ], now: now);
        expect([for (final s in picked) s.name], ['Nueva', 'Vieja']);
      },
    );

    test('lo mejor del año: una por serie, recientes primero, sin las del '
        'banner', () {
      final categories = [
        CategoryColumn(
          columnId: 1,
          columnName: 'Todo',
          movies: [
            season('a1', 'Alfa T1', score: '9.0', year: '2010'),
            season('b1', 'Beta T1', score: '7.0', year: '${now.year}'),
            season('b2', 'Beta T2', score: '7.4', year: '${now.year}'),
            season('c1', 'Gama T1', score: '8.0', year: '${now.year - 1}'),
            season('d1', 'Delta T1', score: '9.9', year: '${now.year}'),
          ],
        ),
      ];
      final best = pickBestSeries(
        categories,
        count: 5,
        exclude: [season('d1', 'Delta')],
        now: now,
      );
      expect([for (final s in best) s.name], ['Gama', 'Beta', 'Alfa']);
      expect(best[1].contentId, 'b2');
    });
  });
}
