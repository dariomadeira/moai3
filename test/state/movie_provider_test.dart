import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/services/movie_service.dart';
import 'package:moai3/state/movie_provider.dart';

void main() {
  group('MovieProvider State Tests (SPEC-38)', () {
    test('loadPopularMovies actualiza el estado de carga y puebla la lista de películas', () async {
      final provider = MovieProvider();

      Future<String> mockFetcher(String url) async {
        return json.encode({
          'metas': [
            {
              'id': 'tt0137523',
              'name': 'El Club de la Pelea',
              'description': 'Sinopsis',
              'poster': 'https://image.com/poster.jpg',
              'year': '1999',
              'imdbRating': 8.8,
            }
          ]
        });
      }

      await provider.loadPopularMovies(customFetcher: mockFetcher);

      expect(provider.isLoading, false);
      expect(provider.movies.length, 1);
      expect(provider.movies.first.title, 'El Club de la Pelea');
    });

    test('selectMovie busca fuentes Torrentio y auto-selecciona la fuente de mayor puntaje', () async {
      final provider = MovieProvider();
      const movie = Movie(
        id: 'tt0137523',
        title: 'El Club de la Pelea',
        overview: 'Overview',
        imdbId: 'tt0137523',
      );

      Future<String> mockFetcher(String url) async {
        if (url == MovieService.torrentioEndpoint('tt0137523')) {
          return json.encode({
            'streams': [
              {
                'name': 'Torrentio 1080p English',
                'title': 'Fight.Club.1080p.English.mkv\n👤 300 💾 2 GB',
                'infoHash': 'hash_en',
              },
              {
                'name': 'Torrentio 1080p Latino',
                'title': 'Fight.Club.1080p.DUAL.Latino.mkv\n👤 80 💾 2.1 GB',
                'infoHash': 'hash_lat',
              }
            ]
          });
        }
        throw Exception('URL no encontrada');
      }

      await provider.selectMovie(movie, customFetcher: mockFetcher);

      expect(provider.selectedMovie?.id, 'tt0137523');
      expect(provider.streams.length, 2);
      expect(provider.selectedStream?.infoHash, 'hash_lat');
      expect(provider.selectedStream?.hasLatinoAudio, true);
    });

    test('clearSelection resetea la película y los streams seleccionados', () async {
      final provider = MovieProvider();
      const movie = Movie(id: '123', title: 'Test', overview: '');

      await provider.selectMovie(movie);
      expect(provider.selectedMovie, isNotNull);

      provider.clearSelection();
      expect(provider.selectedMovie, isNull);
      expect(provider.streams, isEmpty);
      expect(provider.selectedStream, isNull);
    });
  });
}
