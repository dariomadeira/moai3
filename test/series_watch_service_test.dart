import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const total = Duration(minutes: 50);

  Future<void> record(String episode, Duration position, {int count = 3}) =>
      SeriesWatchService.recordProgress(
        seasonId: 's1',
        episodeId: episode,
        episodeCount: count,
        position: position,
        total: total,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('antes de los 3 min no cuenta', () async {
    await record('e1', const Duration(minutes: 2));
    expect(await SeriesWatchService.resumeAt('e1'), isNull);
    expect((await SeriesWatchService.season('s1')).watched, isEmpty);
  });

  test('a la mitad se guarda dónde retomar, sin check', () async {
    await record('e1', const Duration(minutes: 20));
    expect(
      await SeriesWatchService.resumeAt('e1'),
      const Duration(minutes: 20),
    );
    expect((await SeriesWatchService.season('s1')).watched, isEmpty);
  });

  test('a 3 min del final queda visto y ya no retoma', () async {
    await record('e1', const Duration(minutes: 20));
    // 3 min y 1 s antes del final: todavía no.
    await record('e1', total - const Duration(minutes: 3, seconds: 1));
    expect((await SeriesWatchService.season('s1')).watched, isEmpty);

    await record('e1', total - const Duration(minutes: 3));
    expect((await SeriesWatchService.season('s1')).watched, {'e1'});
    expect(await SeriesWatchService.resumeAt('e1'), isNull);
  });

  test('la temporada queda completa con todos sus capítulos vistos', () async {
    for (final e in ['e1', 'e2']) {
      await record(e, total);
    }
    expect((await SeriesWatchService.season('s1')).complete, isFalse);
    await record('e3', total);
    final season = await SeriesWatchService.season('s1');
    expect(season.watched, {'e1', 'e2', 'e3'});
    expect(season.complete, isTrue);
  });

  test('sin saber cuántos capítulos tiene, nunca está completa', () async {
    await record('e1', total, count: 0);
    expect((await SeriesWatchService.season('s1')).complete, isFalse);
    await SeriesWatchService.rememberEpisodeCount('s1', 1);
    expect((await SeriesWatchService.season('s1')).complete, isTrue);
  });

  test(
    'a mano: marcar saca el punto de retomar; desmarcar, la marca',
    () async {
      await record('e1', const Duration(minutes: 20));
      await SeriesWatchService.setWatched(
        seasonId: 's1',
        episodeIds: ['e1', 'e2', 'e3'],
        watched: true,
        episodeCount: 3,
      );
      expect((await SeriesWatchService.season('s1')).complete, isTrue);
      expect(await SeriesWatchService.resumeAt('e1'), isNull);

      await SeriesWatchService.setWatched(
        seasonId: 's1',
        episodeIds: ['e2'],
        watched: false,
        episodeCount: 3,
      );
      final season = await SeriesWatchService.season('s1');
      expect(season.watched, {'e1', 'e3'});
      expect(season.complete, isFalse);
    },
  );

  test('volver a ver uno visto a la mitad no le saca el check', () async {
    await record('e1', total);
    await record('e1', const Duration(minutes: 10));
    expect((await SeriesWatchService.season('s1')).watched, {'e1'});
    expect(
      await SeriesWatchService.resumeAt('e1'),
      const Duration(minutes: 10),
    );
  });

  test('borrar todo: sin capítulos vistos ni dónde retomar', () async {
    await record('e1', total);
    await record('e2', const Duration(minutes: 20));
    await SeriesWatchService.clearAll();
    expect((await SeriesWatchService.season('s1')).watched, isEmpty);
    expect(await SeriesWatchService.resumeAt('e2'), isNull);
  });
}
