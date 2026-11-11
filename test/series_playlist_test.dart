import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// Una temporada [season] (contentId `s2`) con [episodes] capítulos
/// (`s2-e1`, `s2-e2`…).
SeriesSeasonDetail seasonDetail(int season, int episodes) => SeriesSeasonDetail(
  info: MovieItem(contentId: 's$season', name: 'Dark T$season'),
  seasons: const [],
  episodes: [
    for (var n = 1; n <= episodes; n++)
      SeriesEpisode(contentId: 's$season-e$n', number: n),
  ],
);

const _seasons = [
  SeriesSeason(contentId: 's1', number: 1),
  SeriesSeason(contentId: 's2', number: 2),
];

void main() {
  late List<String> fetched;
  late List<String> resolved;
  late Set<String> failing;

  setUp(() {
    useSpanishTranslations();
    SharedPreferences.setMockInitialValues({});
    fetched = [];
    resolved = [];
    failing = {};
  });

  SeriesPlaylist playlist({String season = 's1', int episode = 0}) =>
      SeriesPlaylist(
        seasons: _seasons,
        details: {'s1': seasonDetail(1, 2)},
        startSeasonId: season,
        startEpisodeIndex: episode,
        fetchSeason: (id) async {
          fetched.add(id);
          return seasonDetail(int.parse(id.substring(1)), 3);
        },
        resolveStream: (season, episode, item) async {
          resolved.add(episode.contentId);
          if (failing.contains(episode.contentId)) return null;
          return const ResolvedPlayStream(
            streamUrl: 'https://example.com/v.m3u8',
            quality: '1080P',
            audioInfo: 'spa',
          );
        },
      );

  test('el capítulo como película: "Serie · T1 · Capítulo 1"', () {
    final p = playlist();
    expect(p.item.contentId, 's1-e1');
    expect(p.item.name, 'Dark · T1 · Capítulo 1');
  });

  test('pasa al siguiente de la temporada', () async {
    final p = playlist();
    expect(p.nextLabel, 'Siguiente: Capítulo 2');
    final next = await p.next();
    expect(next?.movie.name, 'Dark · T1 · Capítulo 2');
    expect(resolved, ['s1-e2']);
    expect(p.episodeIndex, 1);
  });

  test('al final de la temporada sigue con la próxima', () async {
    final p = playlist(episode: 1);
    expect(p.nextLabel, 'Siguiente: Temporada 2 · Capítulo 1');
    final next = await p.next();
    expect(fetched, ['s2']);
    expect(next?.movie.name, 'Dark · T2 · Capítulo 1');
    expect(p.seasonId, 's2');
    expect(p.episodeIndex, 0);
    // Lo pedido queda para el detalle y se sabe cuántos capítulos tiene.
    expect(p.details.keys, containsAll(['s1', 's2']));
    await Future<void>.delayed(Duration.zero);
    expect((await SeriesWatchService.season('s2')).episodeCount, 3);
  });

  test('después del último capítulo de la última no hay más', () async {
    final p = SeriesPlaylist(
      seasons: _seasons,
      details: {'s2': seasonDetail(2, 3)},
      startSeasonId: 's2',
      startEpisodeIndex: 2,
      resolveStream: (_, _, _) async => null,
    );
    expect(p.nextLabel, isNull);
    expect(await p.next(), isNull);
    expect(p.seasonId, 's2');
  });

  test('si no se puede pedir el siguiente, se queda y lo dice', () async {
    failing.add('s1-e2');
    final p = playlist();
    expect(await p.next(), isNull);
    expect(p.lastError, isNotNull);
    expect(p.episodeIndex, 0);
  });

  test('lo visto se guarda en su temporada', () async {
    final p = playlist(episode: 1);
    await p.record(const Duration(minutes: 48), const Duration(minutes: 50));
    expect((await SeriesWatchService.season('s1')).watched, {'s1-e2'});
  });

  group('Seguir series', () {
    const total = Duration(minutes: 50);

    test('antes de los 3 min no se anota', () async {
      await playlist().record(const Duration(minutes: 2), total);
      expect(await SeriesContinueService.entries(), isEmpty);
    });

    test('anota la serie, el capítulo y el siguiente', () async {
      await playlist().record(const Duration(minutes: 10), total);
      final [entry] = await SeriesContinueService.entries();
      expect(entry.title, 'Dark');
      expect(entry.current.episodeId, 's1-e1');
      expect(entry.next?.episodeId, 's1-e2');
      expect(entry.next?.seasonNumber, 1);
      expect(entry.seasons.length, 2);
    });

    test('el último de la temporada: sigue el primero de la próxima', () {
      final next = playlist(episode: 1).continueEntry(total).next;
      expect(next?.seasonId, 's2');
      expect(next?.seasonNumber, 2);
      expect(next?.episodeIndex, 0);
    });

    test('el último de la serie: no hay siguiente', () {
      final p = SeriesPlaylist(
        seasons: _seasons,
        details: {'s2': seasonDetail(2, 3)},
        startSeasonId: 's2',
        startEpisodeIndex: 2,
      );
      expect(p.continueEntry(total).next, isNull);
    });

    test('una sola entrada por serie, aunque cambie de temporada', () async {
      await playlist().record(const Duration(minutes: 10), total);
      final p = playlist(episode: 1);
      await p.next();
      await p.record(const Duration(minutes: 10), total);
      final entries = await SeriesContinueService.entries();
      expect(entries.length, 1);
      expect(entries.single.current.seasonId, 's2');
    });
  });

  test('el audio elegido vale para toda la serie', () {
    expect(playlist().audioKey, playlist(episode: 1).audioKey);
  });
}
