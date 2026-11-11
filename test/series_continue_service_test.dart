import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_series_continue_card.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// Una serie vista hasta el capítulo [episode] de la temporada 2 ("s2"),
/// con [next] como el que sigue.
SeriesContinueEntry entry(
  String key, {
  int updatedAt = 1,
  int episode = 5,
  SeriesEpisodeRef? next,
}) => SeriesContinueEntry(
  seriesKey: key,
  title: 'Serie $key',
  seasons: const [
    SeriesSeason(contentId: 's1', number: 1),
    SeriesSeason(contentId: 's2', number: 2),
  ],
  current: SeriesEpisodeRef(
    seasonId: 's2',
    seasonNumber: 2,
    episodeIndex: episode - 1,
    episodeNumber: episode,
    episodeId: '$key-e$episode',
  ),
  next: next,
  episodeCount: 10,
  totalSeconds: 3000,
  updatedAt: updatedAt,
);

const _next = SeriesEpisodeRef(
  seasonId: 's2',
  seasonNumber: 2,
  episodeIndex: 5,
  episodeNumber: 6,
  episodeId: 'a-e6',
);

void main() {
  setUp(() {
    useSpanishTranslations();
    SharedPreferences.setMockInitialValues({});
    SeriesWatchlistService.instance.resetForTest();
  });

  test('una por serie, la última vista primero, hasta el tope', () async {
    await SeriesContinueService.record(entry('a'));
    await SeriesContinueService.record(entry('b', updatedAt: 2));
    await SeriesContinueService.record(entry('a', updatedAt: 3, episode: 6));
    final list = await SeriesContinueService.entries();
    expect([for (final e in list) e.seriesKey], ['a', 'b']);
    expect(list.first.current.episodeNumber, 6);

    for (var i = 0; i < SeriesContinueService.maxSeries + 5; i++) {
      await SeriesContinueService.record(entry('x$i', updatedAt: 10 + i));
    }
    expect(
      (await SeriesContinueService.entries()).length,
      SeriesContinueService.maxSeries,
    );
  });

  test('quitar una y quitar todas', () async {
    await SeriesContinueService.record(entry('a'));
    await SeriesContinueService.record(entry('b', updatedAt: 2));
    await SeriesContinueService.remove('a');
    expect(
      [for (final e in await SeriesContinueService.entries()) e.seriesKey],
      ['b'],
    );
    await SeriesContinueService.clear();
    expect(await SeriesContinueService.entries(), isEmpty);
  });

  test('a la mitad: ese capítulo, con dónde retomarlo', () async {
    await SeriesWatchService.recordProgress(
      seasonId: 's2',
      episodeId: 'a-e5',
      episodeCount: 10,
      position: const Duration(minutes: 25),
      total: const Duration(minutes: 50),
    );
    await SeriesContinueService.record(entry('a', next: _next));
    final [item] = await SeriesContinueService.items();
    expect(item.isNext, isFalse);
    expect(item.episode.episodeNumber, 5);
    expect(item.resumeAt, const Duration(minutes: 25));
    expect(item.progress, closeTo(0.5, 0.01));
    expect(HomeSeriesContinueCard.badgeOf(item), 'T2 · Cap. 5');
  });

  test('terminado (o marcado a mano): el siguiente, sin barra', () async {
    await SeriesWatchService.setWatched(
      seasonId: 's2',
      episodeIds: ['a-e5'],
      watched: true,
      episodeCount: 10,
    );
    await SeriesContinueService.record(entry('a', next: _next));
    final [item] = await SeriesContinueService.items();
    expect(item.isNext, isTrue);
    expect(item.episode.episodeNumber, 6);
    expect(item.progress, isNull);
    expect(HomeSeriesContinueCard.badgeOf(item), 'Sigue: T2 · Cap. 6');
  });

  test('visto el último de la serie: sale y se olvida', () async {
    await SeriesWatchService.setWatched(
      seasonId: 's2',
      episodeIds: ['a-e5'],
      watched: true,
      episodeCount: 10,
    );
    await SeriesContinueService.record(entry('a'));
    expect(await SeriesContinueService.items(), isEmpty);
    expect(await SeriesContinueService.entries(), isEmpty);
  });

  testWidgets('la tarjeta: etiqueta del capítulo sobre cada serie', (
    tester,
  ) async {
    await SeriesContinueService.record(entry('a', next: _next));
    final items = await tester.runAsync(SeriesContinueService.items);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 280,
            child: HomeSeriesContinueCard(items: items!, selectedIndex: 0),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Seguir'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
    expect(find.text('1 en curso'), findsOneWidget);
    expect(find.text('T2 · Cap. 5'), findsOneWidget);
    expect(find.text('Serie a'), findsOneWidget);
  });

  test('avisa cada cambio (el Inicio relee la tarjeta)', () async {
    var changes = 0;
    void count() => changes++;
    SeriesContinueService.changes.addListener(count);
    addTearDown(() => SeriesContinueService.changes.removeListener(count));
    await SeriesContinueService.record(entry('a'));
    expect(changes, 1);
    await SeriesWatchService.setWatched(
      seasonId: 's2',
      episodeIds: ['a-e5'],
      watched: true,
      episodeCount: 10,
    );
    expect(changes, 2);
    await SeriesContinueService.clear();
    await SeriesWatchService.clearAll();
    expect(changes, 4);
  });
}
