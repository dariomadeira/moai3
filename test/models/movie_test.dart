import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie.dart';

void main() {
  group('Movie Model Tests (SPEC-38)', () {
    test('fromTmdbJson deserealiza correctamente datos de TMDB', () {
      final json = {
        'id': 550,
        'title': 'El Club de la Pelea',
        'overview': 'Un oficinista desencantado...',
        'poster_path': '/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg',
        'backdrop_path': '/hZkgoQY85KGDiD68QtfwwzToBwv.jpg',
        'release_date': '1999-10-15',
        'vote_average': 8.433,
        'imdb_id': 'tt0137523',
      };

      final movie = Movie.fromTmdbJson(json);

      expect(movie.id, '550');
      expect(movie.title, 'El Club de la Pelea');
      expect(movie.posterPath, 'https://image.tmdb.org/t/p/w500/pB8BM7pdSp6B6Ih7QZ4DrQ3PmJK.jpg');
      expect(movie.backdropPath, 'https://image.tmdb.org/t/p/w780/hZkgoQY85KGDiD68QtfwwzToBwv.jpg');
      expect(movie.voteAverage, 8.433);
      expect(movie.imdbId, 'tt0137523');
    });

    test('fromCinemetaJson deserealiza datos de Stremio Cinemeta (fallback)', () {
      final json = {
        'id': 'tt0137523',
        'name': 'Fight Club',
        'description': 'An insomniac office worker...',
        'poster': 'https://images.metahub.space/poster/medium/tt0137523/img',
        'background': 'https://images.metahub.space/background/medium/tt0137523/img',
        'year': '1999',
        'imdbRating': '8.8',
      };

      final movie = Movie.fromCinemetaJson(json);

      expect(movie.id, 'tt0137523');
      expect(movie.title, 'Fight Club');
      expect(movie.overview, contains('insomniac'));
      expect(movie.posterPath, 'https://images.metahub.space/poster/medium/tt0137523/img');
      expect(movie.releaseDate, '1999');
      expect(movie.voteAverage, 8.8);
      expect(movie.imdbId, 'tt0137523');
    });

    test('toJson y copyWith funcionan correctamente', () {
      const movie = Movie(
        id: '123',
        title: 'Test Movie',
        overview: 'Overview',
        voteAverage: 7.5,
      );

      final json = movie.toJson();
      expect(json['id'], '123');
      expect(json['title'], 'Test Movie');
      expect(json['vote_average'], 7.5);

      final updated = movie.copyWith(title: 'Updated Title');
      expect(updated.id, '123');
      expect(updated.title, 'Updated Title');
    });
  });
}
