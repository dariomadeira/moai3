import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/movie_service.dart';

void main() {
  group('MovieService Unit Tests (SPEC-38)', () {
    test('parseCinemetaMovies convierte correctamente JSON de Cinemeta a lista de Movie', () {
      final jsonBody = json.encode({
        'metas': [
          {
            'id': 'tt0137523',
            'name': 'El Club de la Pelea',
            'description': 'Sinopsis...',
            'poster': 'https://image.com/poster.jpg',
            'year': '1999',
            'imdbRating': '8.8',
          },
          {
            'id': 'tt0111161',
            'name': 'Sueño de Fuga',
            'description': 'Sinopsis 2...',
            'poster': 'https://image.com/poster2.jpg',
            'year': '1994',
            'imdbRating': '9.3',
          }
        ]
      });

      final movies = MovieService.parseCinemetaMovies(jsonBody);

      expect(movies.length, 2);
      expect(movies[0].id, 'tt0137523');
      expect(movies[0].title, 'El Club de la Pelea');
      expect(movies[0].imdbId, 'tt0137523');
      expect(movies[1].title, 'Sueño de Fuga');
      expect(movies[1].voteAverage, 9.3);
    });

    test('fetchPopularMovies ejecuta fallback a Cinemeta cuando no hay TMDB API Key', () async {
      Future<String> mockFetcher(String url) async {
        if (url == MovieService.cinemetaPopularEndpoint) {
          return json.encode({
            'metas': [
              {
                'id': 'tt0816692',
                'name': 'Interstellar',
                'description': 'Viaje interestelar',
                'poster': 'https://image.com/interstellar.jpg',
                'year': '2014',
                'imdbRating': 8.6,
              }
            ]
          });
        }
        throw Exception('URL desconocida');
      }

      final movies = await MovieService.fetchPopularMovies(
        customFetcher: mockFetcher,
      );

      expect(movies.length, 1);
      expect(movies.first.title, 'Interstellar');
      expect(movies.first.imdbId, 'tt0816692');
    });

    test('parseTorrentioStreams ordena fuentes por score descendente (Audio Latino primero)', () {
      final jsonBody = json.encode({
        'streams': [
          {
            'name': 'Torrentio 1080p',
            'title': 'Movie.2024.1080p.English.mkv\n👤 500 💾 2.0 GB',
            'infoHash': 'hash_english',
          },
          {
            'name': 'Torrentio 1080p Latino',
            'title': 'Movie.2024.1080p.DUAL.Latino.mkv\n👤 100 💾 2.2 GB',
            'infoHash': 'hash_latino',
          },
        ]
      });

      final streams = MovieService.parseTorrentioStreams(jsonBody);

      expect(streams.length, 2);
      // La versión con Audio Latino debe estar primera debido al score (+10000)
      expect(streams.first.infoHash, 'hash_latino');
      expect(streams.first.hasLatinoAudio, true);
      expect(streams.last.infoHash, 'hash_english');
      expect(streams.last.hasLatinoAudio, false);
    });

    test('fetchStreamsForMovie retorna lista vacía si imdbId es inválido o falla red', () async {
      Future<String> mockErrorFetcher(String url) async {
        throw Exception('Network error');
      }

      final streams = await MovieService.fetchStreamsForMovie(
        'tt_invalid',
        customFetcher: mockErrorFetcher,
      );

      expect(streams, isEmpty);
    });
  });
}
