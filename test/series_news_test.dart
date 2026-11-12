import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_series_continue_card.dart';
import 'package:moai3/features/movies/series_news.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:moai3/services/tmdb_series_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

const _s1 = SeriesSeason(contentId: 's1', number: 1);
const _s2 = SeriesSeason(contentId: 's2', number: 2);

/// La temporada 1 de VisionQuest con [episodes] subidos de [planned].
SeriesSeasonDetail season1(
  int episodes, {
  int? planned = 8,
  List<SeriesSeason> seasons = const [_s1],
  String? imdbId,
}) => SeriesSeasonDetail(
  info: MovieItem(contentId: 's1', name: 'VisionQuest T1'),
  seasons: seasons,
  episodes: [
    for (var n = 1; n <= episodes; n++)
      SeriesEpisode(contentId: 's1-e$n', number: n),
  ],
  plannedEpisodes: planned,
  imdbId: imdbId,
);

/// Vista hasta el capítulo 7 (el último subido), sin siguiente.
SeriesContinueEntry upToDate({
  int updatedAt = 1,
  int? planned = 8,
  String? imdbId,
}) => SeriesContinueEntry(
  seriesKey: 'series:s1',
  title: 'VisionQuest',
  seasons: const [_s1],
  current: const SeriesEpisodeRef(
    seasonId: 's1',
    seasonNumber: 1,
    episodeIndex: 6,
    episodeNumber: 7,
    episodeId: 's1-e7',
  ),
  episodeCount: 7,
  totalSeconds: 3000,
  updatedAt: updatedAt,
  plannedEpisodes: planned,
  imdbId: imdbId,
);

Future<void> watchSeason1(int episodes) => SeriesWatchService.setWatched(
  seasonId: 's1',
  episodeIds: [for (var n = 1; n <= episodes; n++) 's1-e$n'],
  watched: true,
  episodeCount: episodes,
);

void main() {
  final today = DateTime(2026, 11, 11, 10);
  final todaySeconds = today.millisecondsSinceEpoch ~/ 1000;

  setUp(() {
    useSpanishTranslations();
    SharedPreferences.setMockInitialValues({});
    SeriesWatchlistService.instance.resetForTest();
  });

  test('el detalle lee cuántos capítulos va a tener la temporada', () {
    final detail = SeriesSeasonDetail.fromAsset({
      'volumnCount': '8',
      'updateCount': '7',
      'simpleProgramList': [
        {'contentId': 'e1', 'seriesNumber': 1},
      ],
    }, MovieItem(contentId: 's1', name: 'VisionQuest T1'));
    expect(detail?.plannedEpisodes, 8);
    expect(detail!.expectsAfter(7), isTrue);
    expect(detail.expectsAfter(8), isFalse);
  });

  test(
    'al día con capítulos por salir: no se muestra pero se recuerda',
    () async {
      await watchSeason1(7);
      await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));
      expect(await SeriesContinueService.items(now: today), isEmpty);
      expect(await SeriesContinueService.entries(), hasLength(1));

      // Temporada completa (8 de 8): terminada, se olvida como antes.
      await SeriesContinueService.record(
        upToDate(updatedAt: todaySeconds, planned: 7),
      );
      expect(await SeriesContinueService.items(now: today), isEmpty);
      expect(await SeriesContinueService.entries(), isEmpty);
    },
  );

  test('después de 6 meses esperando, se olvida', () async {
    await watchSeason1(7);
    await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));
    final later = today.add(const Duration(days: 181));
    expect(await SeriesContinueService.awaiting(now: later), isEmpty);
    await SeriesContinueService.items(now: later);
    expect(await SeriesContinueService.entries(), isEmpty);
  });

  test(
    'cuando aparece el capítulo que faltaba, vuelve con "Capítulo nuevo"',
    () async {
      await watchSeason1(7);
      await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));

      final asked = <String>[];
      final changed = await SeriesNews.check(
        now: today,
        fetchSeason: (id) async {
          asked.add(id);
          return season1(8);
        },
      );
      expect(changed, isTrue);
      expect(asked, ['s1']);

      final items = await SeriesContinueService.items(now: today);
      expect(items, hasLength(1));
      expect(items.single.isNext, isTrue);
      expect(items.single.episode.episodeNumber, 8);
      expect(items.single.episode.episodeId, 's1-e8');
      expect(
        HomeSeriesContinueCard.badgeOf(items.single),
        'Capítulo nuevo · T1 · Cap. 8',
      );
    },
  );

  test('una temporada nueva vuelve con "Temporada nueva"', () async {
    await watchSeason1(7);
    await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));

    await SeriesNews.check(
      now: today,
      fetchSeason: (_) async => season1(7, seasons: const [_s1, _s2]),
    );

    final items = await SeriesContinueService.items(now: today);
    expect(items.single.episode.seasonId, 's2');
    expect(items.single.episode.episodeNumber, 1);
    expect(items.single.entry.seasons.map((s) => s.number), [1, 2]);
    expect(
      HomeSeriesContinueCard.badgeOf(items.single),
      'Temporada nueva · T2',
    );
  });

  test('pregunta una vez por día', () async {
    await watchSeason1(7);
    await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));
    var asked = 0;
    Future<SeriesSeasonDetail?> fetch(String id) async {
      asked++;
      return season1(7);
    }

    await SeriesNews.check(now: today, fetchSeason: fetch);
    await SeriesNews.check(
      now: today.add(const Duration(hours: 5)),
      fetchSeason: fetch,
    );
    expect(asked, 1);
    await SeriesNews.check(
      now: today.add(const Duration(days: 1, hours: 1)),
      fetchSeason: fetch,
    );
    expect(asked, 2);
  });

  test('sin respuesta del portal (sin sesión) vuelve a probar', () async {
    await watchSeason1(7);
    await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));
    var asked = 0;
    await SeriesNews.check(
      now: today,
      fetchSeason: (_) async {
        asked++;
        return null;
      },
    );
    await SeriesNews.check(
      now: today.add(const Duration(minutes: 5)),
      fetchSeason: (_) async {
        asked++;
        return season1(8);
      },
    );
    expect(asked, 2);
    expect(await SeriesContinueService.items(now: today), hasLength(1));
  });

  test('si se quitó a mano, no vuelve', () async {
    await watchSeason1(7);
    await SeriesContinueService.record(upToDate(updatedAt: todaySeconds));
    await SeriesNews.check(now: today, fetchSeason: (_) async => season1(7));
    await SeriesContinueService.remove('series:s1');

    var asked = 0;
    await SeriesNews.check(
      now: today.add(const Duration(days: 1, hours: 1)),
      fetchSeason: (_) async {
        asked++;
        return season1(8);
      },
    );
    expect(asked, 0);
    expect(await SeriesContinueService.entries(), isEmpty);
  });

  test(
    'rescate: una serie al día que ya se había olvidado vuelve a esperar',
    () async {
      // Vistos los 7 de la temporada, sin nada en "Seguir series" (como
      // quedaba antes de esto).
      await watchSeason1(7);
      await SeriesNews.check(now: today, fetchSeason: (_) async => season1(7));
      final entries = await SeriesContinueService.entries();
      expect(entries, hasLength(1));
      expect(entries.single.awaiting, isTrue);
      expect(await SeriesContinueService.items(now: today), isEmpty);

      // Al otro día ya está el 8.
      await SeriesNews.check(
        now: today.add(const Duration(days: 1, hours: 1)),
        fetchSeason: (_) async => season1(8),
      );
      final items = await SeriesContinueService.items(now: today);
      expect(items.single.episode.episodeNumber, 8);
    },
  );

  test('rescate: una temporada completa y sin otra no entra', () async {
    await watchSeason1(7);
    await SeriesNews.check(
      now: today,
      fetchSeason: (_) async => season1(7, planned: 7),
    );
    expect(await SeriesContinueService.entries(), isEmpty);
  });

  group('temporadas nuevas (TMDb)', () {
    /// TMDb falso: [tv] es la respuesta de `/tv/{id}`; cuenta los pedidos.
    TmdbSeriesService fakeTmdb(Map<String, dynamic>? tv, List<String> log) =>
        TmdbSeriesService(
          fetchJson: (path, query) async {
            log.add(path);
            if (path.startsWith('/find/')) {
              return tv == null
                  ? {'tv_results': []}
                  : {
                      'tv_results': [
                        {'id': 99},
                      ],
                    };
            }
            return tv;
          },
        );

    /// Vista toda (8 de 8, sin otra temporada), con id de IMDb.
    Future<void> finished() async {
      await watchSeason1(8);
      await SeriesContinueService.record(
        upToDate(updatedAt: todaySeconds, planned: 7, imdbId: 'tt1'),
      );
    }

    test('el detalle lee el id de IMDb de keyWords', () {
      final detail = SeriesSeasonDetail.fromAsset({
        'keyWords': 'tt23112594',
      }, MovieItem(contentId: 's1', name: 'VisionQuest T1'));
      expect(detail?.imdbId, 'tt23112594');
    });

    test('TMDb: estado, temporadas y próximo capítulo', () async {
      final log = <String>[];
      final status = await fakeTmdb({
        'status': 'Returning Series',
        'number_of_seasons': 2,
        'next_episode_to_air': {'air_date': '2027-03-01', 'season_number': 2},
      }, log).statusOf('tt1');
      expect(log, ['/find/tt1', '/tv/99']);
      expect(status?.continues, isTrue);
      expect(status?.seasons, 2);
      expect(status?.nextSeason, 2);
      expect(status?.nextAirDate, DateTime(2027, 3));
      expect(
        (await fakeTmdb({'status': 'Ended'}, log).statusOf('tt1'))?.continues,
        isFalse,
      );
      expect(await fakeTmdb(null, log).statusOf('tt1'), isNull);
    });

    test('terminada en TMDb: se olvida', () async {
      await finished();
      expect((await SeriesContinueService.entries()).single.awaiting, isTrue);
      final log = <String>[];
      var asked = 0;
      await SeriesNews.check(
        now: today,
        tmdb: fakeTmdb({'status': 'Ended', 'number_of_seasons': 1}, log),
        fetchSeason: (_) async {
          asked++;
          return season1(7, planned: 7, imdbId: 'tt1');
        },
      );
      expect(asked, 0);
      await SeriesContinueService.items(now: today);
      expect(await SeriesContinueService.entries(), isEmpty);
    });

    test('sigue con fecha: espera la fecha y después aparece', () async {
      await finished();
      final log = <String>[];
      final tmdb = fakeTmdb({
        'status': 'Returning Series',
        'number_of_seasons': 2,
        'next_episode_to_air': {'air_date': '2027-03-01', 'season_number': 2},
      }, log);
      var asked = 0;
      Future<SeriesSeasonDetail?> fetch(String id) async {
        asked++;
        return season1(7, imdbId: 'tt1', seasons: const [_s1, _s2]);
      }

      await SeriesNews.check(now: today, tmdb: tmdb, fetchSeason: fetch);
      expect(asked, 0, reason: 'antes de la fecha no se pregunta');
      expect(await SeriesContinueService.items(now: today), isEmpty);

      final later = DateTime(2027, 3, 2);
      await SeriesNews.check(now: later, tmdb: tmdb, fetchSeason: fetch);
      expect(asked, 1);
      final items = await SeriesContinueService.items(now: later);
      expect(
        HomeSeriesContinueCard.badgeOf(items.single),
        'Temporada nueva · T2',
      );
    });

    test('terminada en TMDb pero con más temporadas que la vista: sigue', () {
      final entry = SeriesNews.withStatus(
        upToDate(planned: 7, imdbId: 'tt1'),
        const TmdbSeriesStatus(continues: false, seasons: 2),
        today,
      );
      expect(entry.continues, isTrue);
      expect(entry.awaiting, isTrue);
    });

    test('sin respuesta de TMDb se sigue preguntando al portal', () async {
      await finished();
      var asked = 0;
      await SeriesNews.check(
        now: today,
        tmdb: fakeTmdb(null, []),
        fetchSeason: (_) async {
          asked++;
          return season1(7, planned: 7, imdbId: 'tt1');
        },
      );
      expect(asked, 1);
      expect(await SeriesContinueService.entries(), hasLength(1));
    });

    test(
      'rescate: una serie vista entera con id de IMDb entra a esperar',
      () async {
        await watchSeason1(7);
        await SeriesNews.check(
          now: today,
          tmdb: fakeTmdb({'status': 'Returning Series'}, []),
          fetchSeason: (_) async => season1(7, planned: 7, imdbId: 'tt1'),
        );
        final entry = (await SeriesContinueService.entries()).single;
        expect(entry.awaitingSeason, isTrue);
        expect(entry.continues, isTrue);
      },
    );
  });
}
