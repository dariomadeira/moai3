import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

MovieItem serie(String id, String name) =>
    MovieItem(contentId: id, name: name, programType: 'teleplay');

void main() {
  final watchlist = SeriesWatchlistService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watchlist.resetForTest();
  });

  test('marcar y desmarcar; la última primero', () async {
    expect(await watchlist.toggle(serie('a1', 'A'), ['a1', 'a2']), isTrue);
    expect(await watchlist.toggle(serie('b1', 'B'), ['b1']), isTrue);
    expect([for (final s in watchlist.items) s.name], ['B', 'A']);
    expect(await watchlist.toggle(serie('a1', 'A'), ['a1']), isFalse);
    expect([for (final s in watchlist.items) s.name], ['B']);
  });

  test('se reconoce por cualquiera de sus temporadas', () async {
    await watchlist.toggle(serie('p1', 'Bobs Burgers'), ['p1', 's1', 's2']);
    expect(watchlist.contains(['s2']), isTrue);
    expect(watchlist.contains(['x9']), isFalse);
    // Desmarcar desde otra temporada (o versión) quita la misma serie.
    expect(await watchlist.toggle(serie('s1', 'Bob'), ['s1']), isFalse);
    expect(watchlist.items, isEmpty);
  });

  test('queda guardada', () async {
    await watchlist.toggle(serie('a1', 'A'), ['a1', 'a2']);
    watchlist.resetForTest();
    await watchlist.ensureLoaded();
    expect(watchlist.contains(['a2']), isTrue);
  });

  test('empezada (anotada en Seguir series), sale de Marcadas', () async {
    await watchlist.toggle(serie('s1', 'A'), ['s1', 's2']);
    await watchlist.toggle(serie('b1', 'B'), ['b1']);
    await SeriesContinueService.record(
      const SeriesContinueEntry(
        seriesKey: 'series:s1',
        title: 'A',
        seasons: [
          SeriesSeason(contentId: 's1', number: 1),
          SeriesSeason(contentId: 's2', number: 2),
        ],
        current: SeriesEpisodeRef(
          seasonId: 's2',
          seasonNumber: 2,
          episodeIndex: 0,
          episodeNumber: 1,
          episodeId: 'e1',
        ),
        episodeCount: 8,
        totalSeconds: 3000,
        updatedAt: 1,
      ),
    );
    expect([for (final s in watchlist.items) s.name], ['B']);
  });

  test('desmarcar todas', () async {
    await watchlist.toggle(serie('a1', 'A'), ['a1']);
    await watchlist.clear();
    expect(watchlist.items, isEmpty);
  });
}
