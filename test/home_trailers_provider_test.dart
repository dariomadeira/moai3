import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/tmdb_trailers_service.dart';
import 'package:moai3/state/home_trailers_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_tmdb_trailers.dart';

void main() {
  group('TmdbTrailersService.parsePick', () {
    test('arma la película con los datos de TMDb y el video', () {
      final pick = TmdbTrailersService.parsePick(
        tmdbMovie(
          7,
          'Weapons',
          videos: [tmdbVideo('abc', published: '2026-10-05T12:00:00.000Z')],
        ),
      )!;
      final movie = pick.movie;
      expect(movie.contentId, 'tmdb_7');
      expect(movie.name, 'Weapons');
      expect(movie.youtubeTrailerKey, 'abc');
      expect(movie.isTrailer, isTrue);
      expect(movie.isMovie, isFalse);
      expect(movie.backdrop, 'https://image.tmdb.org/t/p/w1280/fondo.jpg');
      expect(movie.poster, 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(movie.description, 'De qué trata.');
      expect(movie.formattedYear, '2026');
      expect(movie.formattedScore, '7.3');
      expect(movie.genreList, ['Acción']);
      expect(pick.published, DateTime.utc(2026, 10, 5, 12));
    });

    test('prefiere el trailer en castellano, después el oficial', () {
      String? keyOf(List<Map<String, dynamic>> videos) =>
          TmdbTrailersService.parsePick(
            tmdbMovie(1, 'X', videos: videos),
          )?.movie.youtubeTrailerKey;

      expect(
        keyOf([
          tmdbVideo('en', published: '2026-10-09T00:00:00.000Z'),
          tmdbVideo('es', lang: 'es', published: '2026-10-01T00:00:00.000Z'),
        ]),
        'es',
      );
      expect(
        keyOf([tmdbVideo('fan', official: false), tmdbVideo('oficial')]),
        'oficial',
      );
      // Entre iguales, el más nuevo.
      expect(
        keyOf([
          tmdbVideo('viejo', published: '2026-09-01T00:00:00.000Z'),
          tmdbVideo('nuevo', published: '2026-10-01T00:00:00.000Z'),
        ]),
        'nuevo',
      );
    });

    test('sin trailer usa el teaser; sin nada de YouTube no hay adelanto', () {
      String? keyOf(List<Map<String, dynamic>> videos) =>
          TmdbTrailersService.parsePick(
            tmdbMovie(1, 'X', videos: videos),
          )?.movie.youtubeTrailerKey;

      expect(
        keyOf([
          tmdbVideo('clip', type: 'Clip'),
          tmdbVideo('teaser', type: 'Teaser'),
        ]),
        'teaser',
      );
      expect(keyOf([tmdbVideo('vimeo', site: 'Vimeo')]), isNull);
      expect(keyOf([tmdbVideo('detras', type: 'Behind the Scenes')]), isNull);
      expect(keyOf(const []), isNull);
    });

    test('sin fondo en TMDb usa la miniatura del video', () {
      final pick = TmdbTrailersService.parsePick(
        tmdbMovie(1, 'X', backdrop: null, videos: [tmdbVideo('abc')]),
      )!;
      expect(pick.movie.backdrop, 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
    });
  });

  group('HomeTrailersProvider', () {
    late AppPreferences prefs;
    var now = DateTime(2026, 11, 3, 10);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.init();
      now = DateTime(2026, 11, 3, 10);
    });

    /// 8 películas: la `i` tiene el trailer publicado el día `i` de octubre;
    /// la 9 no tiene trailer.
    Map<int, Map<String, dynamic>> eightMovies() => {
      for (var i = 1; i <= 8; i++)
        i: tmdbMovie(
          i,
          'Película $i',
          videos: [
            tmdbVideo(
              'v$i',
              published: '2026-10-${'$i'.padLeft(2, '0')}T00:00:00.000Z',
            ),
          ],
        ),
      9: tmdbMovie(9, 'Sin trailer'),
    };

    HomeTrailersProvider provider(TmdbTrailersService service) =>
        HomeTrailersProvider(prefs, service: service, now: () => now);

    test('los 6 con el trailer más nuevo, sin repetir', () async {
      final trailers = provider(
        fakeTmdbTrailers(
          nowPlaying: [1, 2, 3, 9],
          upcoming: [4, 5, 6, 7, 8, 3],
          movies: eightMovies(),
        ),
      );
      await trailers.load();
      expect(trailers.trailers.map((m) => m.youtubeTrailerKey), [
        'v8',
        'v7',
        'v6',
        'v5',
        'v4',
        'v3',
      ]);
    });

    test('al arrancar muestra lo guardado sin salir a la red', () async {
      await provider(
        fakeTmdbTrailers(nowPlaying: [1, 2], movies: eightMovies()),
      ).load();

      final calls = <String>[];
      final again = provider(fakeTmdbTrailers(calls: calls, offline: true));
      // Antes de load(): ya están.
      expect(again.trailers.map((m) => m.name), ['Película 2', 'Película 1']);
      expect(again.trailers.first.isTrailer, isTrue);
      await again.load();
      expect(calls, isEmpty);
    });

    test('pasadas 12 h renueva y sólo pide las películas nuevas', () async {
      await provider(
        fakeTmdbTrailers(nowPlaying: [1, 2], movies: eightMovies()),
      ).load();

      now = now.add(const Duration(hours: 13));
      final calls = <String>[];
      final again = provider(
        fakeTmdbTrailers(
          nowPlaying: [1, 2, 3],
          movies: eightMovies(),
          calls: calls,
        ),
      );
      await again.load();
      expect(
        calls.where(
          (c) =>
              c.startsWith('/movie/') &&
              c != '/movie/now_playing' &&
              c != '/movie/upcoming',
        ),
        ['/movie/3'],
      );
      expect(again.trailers.map((m) => m.youtubeTrailerKey), [
        'v3',
        'v2',
        'v1',
      ]);
    });

    test('sin red quedan los de antes', () async {
      final trailers = provider(
        fakeTmdbTrailers(nowPlaying: [1], movies: eightMovies()),
      );
      await trailers.load();

      now = now.add(const Duration(days: 2));
      final again = provider(fakeTmdbTrailers(offline: true));
      await again.load();
      expect(again.trailers.map((m) => m.youtubeTrailerKey), ['v1']);
    });

    test('sin clave ni red no hay adelantos y no falla', () async {
      final trailers = provider(fakeTmdbTrailers(offline: true));
      await trailers.load();
      expect(trailers.trailers, isEmpty);
    });
  });
}
