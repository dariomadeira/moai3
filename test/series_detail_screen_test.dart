import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_series_continue_card.dart';
import 'package:moai3/features/movies/screens/series_detail_screen.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/services/series_recommendations_api.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/state/series_recommendations_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// Como llega del portal (recortado de una respuesta real de "Caballos
/// lentos T6").
Map<String, dynamic> asset({
  required String id,
  required int season,
  required int episodes,
  int seasons = 3,
}) => {
  'contentId': id,
  'name': 'Caballos lentos T$season',
  'alias': 'Slow Horses S$season',
  // Dos, pegados con coma como llegan del portal.
  'director': 'Mick Herron,James Hawes',
  'actorDisplay': 'Gary Oldman,Jack Lowden',
  'score': 8.3,
  'releaseTime': '202$season-09-16',
  'tags': 'Drama,Thriller',
  'description': 'Agentes del MI5 en un departamento de vertedero.',
  'programType': 'teleplay',
  'simpleProgramList': [
    // Desordenados a propósito.
    for (var n = episodes; n >= 1; n--)
      {
        'contentId': '$id-e$n',
        'name': 'Caballos lentos T${season}_$n',
        'duration': n == 1 ? '00:50:00' : '',
        'seriesNumber': n,
        'posterList': [],
      },
  ],
  'sameSeasonSeriesList': [
    for (var s = seasons; s >= 1; s--) {'contentId': 's$s', 'seasonNumber': s},
  ],
  'posterList': [],
};

SeriesSeasonDetail detail(Map<String, dynamic> raw) =>
    SeriesSeasonDetail.fromAsset(
      raw,
      MovieItem.fromJson({
        ...raw,
        'year': raw['releaseTime'].toString().substring(0, 4),
      }),
    )!;

void main() {
  group('temporadas repetidas', () {
    SeriesSeasonDetail version(
      String id, {
      String audio = '',
      String subs = '',
      String? description,
    }) => SeriesSeasonDetail(
      info: MovieItem(contentId: id, name: id, description: description),
      seasons: const [],
      episodes: const [],
      audioInfo: audio,
      subsInfo: subs,
    );

    test('la más completa: idiomas, subtítulos y sinopsis', () {
      expect(version('a', audio: 'und', subs: 'null').completeness, 0);
      expect(
        version(
          'b',
          audio: 'por,eng,spa',
          subs: 'pt,es,en',
          description: 'Bob…',
        ).completeness,
        7,
      );
    });

    test('una por número; mientras no se conocen, la primera', () {
      const all = [
        SeriesSeason(contentId: 'paralela1', number: 1),
        SeriesSeason(contentId: 'oficial1', number: 1),
        SeriesSeason(contentId: 's2', number: 2),
      ];
      expect(SeriesSeasonDetail.duplicated(all), ['paralela1', 'oficial1']);
      expect(
        [for (final s in SeriesSeasonDetail.bestSeasons(all, {})) s.contentId],
        ['paralela1', 's2'],
      );
      final details = {
        'paralela1': version('paralela1', audio: 'und'),
        'oficial1': version('oficial1', audio: 'eng,spa', subs: 'es'),
      };
      expect(
        [
          for (final s in SeriesSeasonDetail.bestSeasons(all, details))
            s.contentId,
        ],
        ['oficial1', 's2'],
      );
    });
  });

  group('SeriesSeasonDetail', () {
    test('temporadas y capítulos, ordenados por número', () {
      final d = detail(asset(id: 's2', season: 2, episodes: 6));
      expect([for (final s in d.seasons) s.number], [1, 2, 3]);
      expect(d.seasons[1].contentId, 's2');
      expect([for (final e in d.episodes) e.number], [1, 2, 3, 4, 5, 6]);
      expect(d.episodes.first.duration, '00:50:00');
      expect(d.episodes[1].duration, isNull);
      expect(d.info.director, 'Mick Herron,James Hawes');
      expect(d.info.formattedDirector, 'Mick Herron, James Hawes');
    });

    test('el título sin la temporada', () {
      expect(
        SeriesSeasonDetail.seriesTitle('Caballos lentos T6'),
        'Caballos lentos',
      );
      expect(SeriesSeasonDetail.seriesTitle('Slow Horses S6'), 'Slow Horses');
      expect(SeriesSeasonDetail.seriesTitle('Lost - Temporada 2'), 'Lost');
      expect(SeriesSeasonDetail.seriesTitle('Dark'), 'Dark');
      expect(SeriesSeasonDetail.seriesTitle('T2'), 'T2');
    });
  });

  group('SeriesDetailScreen', () {
    late AppPreferences prefs;
    late List<String> requested;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.init();
      requested = [];
      SeriesWatchlistService.instance.resetForTest();
    });

    Future<SeriesDetailScreenState> pump(
      WidgetTester tester, {
      int seasons = 3,
      Map<String, int> episodes = const {'s1': 30, 's2': 6, 's3': 9},
      Set<String> failing = const {},
      String open = 's1',
      EpisodeStreamResolver? resolveEpisode,
    }) async {
      useSpanishTranslations();
      // El TV: 960×540 puntos.
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<SeriesSeasonDetail?> fetch(String id) async {
        requested.add(id);
        if (failing.contains(id)) return null;
        final season = int.parse(id.substring(1));
        return detail(
          asset(
            id: id,
            season: season,
            episodes: episodes[id] ?? 6,
            seasons: seasons,
          ),
        );
      }

      final number = int.parse(open.substring(1));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: SeriesDetailScreen(
              series: MovieItem(
                contentId: open,
                name: 'Caballos lentos T$number',
                programType: 'teleplay',
              ),
              fetchSeason: fetch,
              resolveEpisode: resolveEpisode,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state<SeriesDetailScreenState>(
        find.byType(SeriesDetailScreen),
      );
    }

    Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pump();
    }

    /// Una temporada o un capítulo de las filas (los dos dicen "1"…).
    Finder season(int n) => find.byKey(ValueKey('season-$n'));
    Finder episode(int n) => find.byKey(ValueKey('episode-$n'));

    testWidgets('la ficha, las temporadas y los capítulos', (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      // El título sin "T1"; el alias igual.
      expect(find.text('Caballos lentos'), findsOneWidget);
      expect(find.text('Slow Horses'), findsOneWidget);
      expect(find.text('3 temporadas'), findsOneWidget);
      expect(find.text('30 capítulos'), findsOneWidget);
      // Los directores separados como el elenco.
      expect(find.text('Mick Herron, James Hawes'), findsOneWidget);
      // Cada fila con su rótulo, en el gris de "Director:".
      expect(find.text('Temporadas'), findsOneWidget);
      expect(find.text('Capítulos'), findsOneWidget);
      // Las temporadas, sólo con el número (sin "T").
      for (final s in [1, 2, 3]) {
        expect(
          find.descendant(of: season(s), matching: find.text('$s')),
          findsOneWidget,
        );
      }
      expect(find.text('T1'), findsNothing);
      // Una fila: lo que entra; el resto, al correrla.
      expect(episode(1), findsOneWidget);
      expect(episode(30), findsNothing);
      expect(requested, ['s1']);
    });

    Rect tile(WidgetTester tester, int number) =>
        tester.getRect(episode(number));

    Finder dotsRow([String id = 'episodes']) =>
        find.byKey(ValueKey('${id}_dots'));

    /// Los puntos de una fila ('episodes' o 'seasons'): cuántos y cuál es
    /// el encendido (el estirado); null si la fila no tiene.
    ({int pages, int active})? dots(
      WidgetTester tester, [
      String id = 'episodes',
    ]) {
      final row = dotsRow(id);
      if (row.evaluate().isEmpty) return null;
      final widths = [
        for (final dot in tester.widgetList<AnimatedContainer>(
          find.descendant(of: row, matching: find.byType(AnimatedContainer)),
        ))
          dot.constraints!.maxWidth,
      ];
      final widest = widths.reduce((a, b) => a > b ? a : b);
      return (pages: widths.length, active: widths.indexOf(widest));
    }

    testWidgets('la fila llena el ancho, pareja, con los puntos abajo', (
      tester,
    ) async {
      await pump(tester);
      final row = tester.getRect(dotsRow());
      final shown = [
        for (var n = 1; n <= 30; n++)
          if (episode(n).evaluate().isNotEmpty) n,
      ];
      expect(shown.first, 1);
      final first = tile(tester, shown.first);
      final last = tile(tester, shown.last);
      // De punta a punta de la fila; los puntos, debajo.
      expect(first.left, moreOrLessEquals(row.left, epsilon: 0.5));
      expect(last.right, moreOrLessEquals(row.right, epsilon: 0.5));
      expect(row.top, greaterThan(first.bottom));
      // Rectángulos, todos iguales.
      expect(first.width, greaterThanOrEqualTo(64));
      expect(first.height, SeriesDetailScreenState.episodeHeight);
      expect(last.width, moreOrLessEquals(first.width));
    });

    testWidgets('con pocos capítulos, del mismo tamaño y desde la izquierda', (
      tester,
    ) async {
      await pump(tester, episodes: const {'s1': 3, 's2': 6, 's3': 9});
      // Entran todos: sin puntos, y el capítulo 1 debajo de la temporada 1.
      expect(dots(tester), isNull);
      expect(dots(tester, 'seasons'), isNull);
      final first = tester.getRect(season(1));
      expect(tile(tester, 1).left, moreOrLessEquals(first.left, epsilon: 0.5));
      expect(tile(tester, 3).width, moreOrLessEquals(tile(tester, 1).width));
    });

    testWidgets('con muchísimos capítulos, sólo los puntos de alrededor', (
      tester,
    ) async {
      // Como One Piece: más de cien páginas no entran (y antes desbordaban).
      final state = await pump(tester, episodes: const {'s1': 1180});
      expect(dots(tester)!.pages, lessThanOrEqualTo(24));
      expect(dots(tester)!.active, 0);
      for (var i = 0; i < 400; i++) {
        await key(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(state.debugEpisodeIndex, 400);
      // La actual, en el medio de los que se ven.
      expect(dots(tester)!.active, 12);
    });

    testWidgets('dos versiones de la temporada 1: queda una, la completa', (
      tester,
    ) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // Como Bob's Burgers: "p1" es la carga paralela (sin idiomas) y "s1"
      // la oficial; las dos se listan con el número 1.
      Map<String, dynamic> raw(String id, int season, String audio) => {
        ...asset(id: id, season: season, episodes: 3, seasons: 2),
        'audioInfo': audio,
        'sameSeasonSeriesList': [
          {'contentId': 'p1', 'seasonNumber': 1},
          {'contentId': 's1', 'seasonNumber': 1},
          {'contentId': 's2', 'seasonNumber': 2},
        ],
      };
      final versions = {
        'p1': raw('p1', 1, 'und'),
        's1': raw('s1', 1, 'por,eng,spa'),
        's2': raw('s2', 2, 'spa'),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: SeriesDetailScreen(
              // Se abre la paralela (p. ej. desde el buscador).
              series: MovieItem(contentId: 'p1', name: 'Bobs Burgers 1'),
              fetchSeason: (id) async {
                requested.add(id);
                return detail(versions[id]!);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<SeriesDetailScreenState>(
        find.byType(SeriesDetailScreen),
      );
      expect(requested, containsAll(['p1', 's1']));
      expect(season(1), findsOneWidget);
      expect(season(2), findsOneWidget);
      expect(state.debugSeasonId, 's1');
    });

    testWidgets('con una sola temporada está su fila (para marcarla), sin '
        '"N temporadas"', (tester) async {
      await pump(tester, seasons: 1);
      expect(season(1), findsOneWidget);
      expect(find.text('Temporadas'), findsOneWidget);
      expect(find.text('Capítulos'), findsOneWidget);
      expect(find.textContaining('temporadas'), findsNothing);
      // ↑ desde los capítulos va a la temporada.
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_seasons',
      );
    });

    testWidgets('si el portal no lista temporadas, está la abierta', (
      tester,
    ) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: SeriesDetailScreen(
              series: MovieItem(contentId: 's1', name: 'Caballos lentos T1'),
              fetchSeason: (id) async => detail({
                ...asset(id: id, season: 1, episodes: 3),
                'sameSeasonSeriesList': const [],
              }),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(season(1), findsOneWidget);
    });

    testWidgets('←/→ recorren la fila y la corren para los dos lados', (
      tester,
    ) async {
      final state = await pump(tester);
      final pages = dots(tester)!.pages;
      expect(pages, greaterThan(1));
      expect(dots(tester)!.active, 0);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(state.debugEpisodeIndex, 1);
      // Hasta el último: se corrió y no hay más a la derecha.
      for (var i = 0; i < 40; i++) {
        await key(tester, LogicalKeyboardKey.arrowRight);
      }
      expect(state.debugEpisodeIndex, 29);
      expect(episode(30), findsOneWidget);
      expect(episode(1), findsNothing);
      expect(dots(tester)!.active, pages - 1);
      // Y de vuelta.
      for (var i = 0; i < 29; i++) {
        await key(tester, LogicalKeyboardKey.arrowLeft);
      }
      expect(state.debugEpisodeIndex, 0);
      expect(episode(1), findsOneWidget);
      expect(dots(tester)!.active, 0);
      // ↓ no hace nada; el foco sigue en la fila.
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_episodes',
      );
    });

    testWidgets('↑ desde la primera fila va a las temporadas; ←/→ las '
        'cambian y piden la nueva', (tester) async {
      final state = await pump(tester);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(state.debugSeasonId, 's2');
      // Espera un momento antes de pedirla.
      expect(requested, ['s1']);
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(requested, ['s1', 's2']);
      expect(find.text('6 capítulos'), findsOneWidget);
      expect(episode(7), findsNothing);

      // Volver a una ya pedida no la pide otra vez.
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(state.debugSeasonId, 's1');
      expect(requested, ['s1', 's2']);
      expect(find.text('30 capítulos'), findsOneWidget);

      // ↓ vuelve a los capítulos, desde el primero.
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(state.debugEpisodeIndex, 0);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(state.debugEpisodeIndex, 1);
    });

    testWidgets('mientras llega una temporada, una línea de carga '
        'indeterminada (sin ruedita)', (tester) async {
      await pump(tester);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowRight);
      // s2 todavía no se pidió: la fila espera con la línea.
      final loading = find.byKey(const ValueKey('episodes_loading'));
      expect(loading, findsOneWidget);
      final line = tester.widget<LinearProgressIndicator>(
        find.descendant(
          of: loading,
          matching: find.byType(LinearProgressIndicator),
        ),
      );
      expect(line.value, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Del alto de la fila: no salta al llegar.
      expect(
        tester.getSize(loading).height,
        SeriesDetailScreenState.episodeHeight,
      );
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(loading, findsNothing);
      expect(find.text('6 capítulos'), findsOneWidget);
    });

    testWidgets('recorrer rápido no pide todas', (tester) async {
      final state = await pump(tester);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(state.debugSeasonId, 's3');
      expect(requested, ['s1', 's3']);
    });

    testWidgets('abre en la temporada que se eligió en el catálogo', (
      tester,
    ) async {
      final state = await pump(tester, open: 's2');
      expect(state.debugSeasonId, 's2');
      expect(find.text('6 capítulos'), findsOneWidget);
    });

    testWidgets('si la abierta no está en la lista, la reconoce por el número '
        'del nombre', (tester) async {
      // "x2" no figura entre s1, s2 y s3, pero se llama "… T2".
      final state = await pump(tester, open: 'x2');
      expect(state.debugSeasonId, 's2');
      // Marcada como la que se ve.
      final pill = tester.widget<Container>(
        find.descendant(of: season(2), matching: find.byType(Container)).first,
      );
      final other = tester.widget<Container>(
        find.descendant(of: season(1), matching: find.byType(Container)).first,
      );
      expect(pill.decoration, isNot(equals(other.decoration)));
      // Ir a otra y volver no la pide de nuevo.
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      await key(tester, LogicalKeyboardKey.arrowRight);
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(state.debugSeasonId, 's2');
      expect(requested, ['x2', 's1']);
    });

    testWidgets('muchas temporadas: fila con puntos, alineada con los '
        'capítulos', (tester) async {
      final state = await pump(tester, seasons: 14);
      expect(dots(tester, 'seasons')!.active, 0);
      expect(dots(tester)!.active, 0);
      expect(
        tester.getRect(season(1)).center.dx,
        moreOrLessEquals(tile(tester, 1).center.dx, epsilon: 0.5),
      );
      await key(tester, LogicalKeyboardKey.arrowUp);
      for (var i = 0; i < 13; i++) {
        await key(tester, LogicalKeyboardKey.arrowRight);
      }
      await tester.pump(SeriesDetailScreenState.seasonLoadDelay);
      await tester.pumpAndSettle();
      expect(state.debugSeasonId, 's14');
      expect(season(14), findsOneWidget);
      expect(season(1), findsNothing);
      final seasons = dots(tester, 'seasons')!;
      expect(seasons.active, seasons.pages - 1);
    });

    testWidgets('si no cargan, lo dice y OK reintenta', (tester) async {
      final failing = {'s1'};
      await pump(tester, failing: failing);
      expect(find.text('No se pudieron cargar los capítulos.'), findsOneWidget);
      failing.clear();
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(requested, ['s1', 's1']);
      expect(find.text('30 capítulos'), findsOneWidget);
    });

    testWidgets('check en los capítulos vistos y en la temporada completa', (
      tester,
    ) async {
      // s1: vistos el 1 y el 3; s2: los 6, completa.
      await SeriesWatchService.recordProgress(
        seasonId: 's1',
        episodeId: 's1-e1',
        episodeCount: 30,
        position: const Duration(minutes: 50),
        total: const Duration(minutes: 50),
      );
      await SeriesWatchService.recordProgress(
        seasonId: 's1',
        episodeId: 's1-e3',
        episodeCount: 30,
        position: const Duration(minutes: 50),
        total: const Duration(minutes: 50),
      );
      for (var n = 1; n <= 6; n++) {
        await SeriesWatchService.recordProgress(
          seasonId: 's2',
          episodeId: 's2-e$n',
          episodeCount: 6,
          position: const Duration(minutes: 50),
          total: const Duration(minutes: 50),
        );
      }
      await pump(tester);
      Finder check(Finder of) => find.descendant(
        of: of,
        matching: find.byKey(const ValueKey('watched')),
      );
      expect(check(episode(1)), findsOneWidget);
      expect(check(episode(2)), findsNothing);
      expect(check(episode(3)), findsOneWidget);
      expect(check(season(1)), findsNothing);
      expect(check(season(2)), findsOneWidget);
      expect(check(season(3)), findsNothing);
    });

    /// OK mantenido (más que [TvTiming.longPress]).
    Future<void> holdOk(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      // Lo guardado se lee de nuevo: dejar que terminen las esperas.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    Finder check(Finder of) => find.descendant(
      of: of,
      matching: find.byKey(const ValueKey('watched')),
    );

    testWidgets('OK mantenido en un capítulo lo marca y lo desmarca, sin '
        'reproducirlo', (tester) async {
      var resolved = 0;
      await pump(
        tester,
        resolveEpisode: (_, _, _) async {
          resolved++;
          return null;
        },
      );
      await key(tester, LogicalKeyboardKey.arrowRight);
      await holdOk(tester);
      expect(check(episode(2)), findsOneWidget);
      expect(check(episode(1)), findsNothing);
      expect((await SeriesWatchService.season('s1')).watched, {'s1-e2'});

      await holdOk(tester);
      expect(check(episode(2)), findsNothing);
      expect((await SeriesWatchService.season('s1')).watched, isEmpty);
      expect(resolved, 0);
    });

    testWidgets('OK mantenido en la temporada marca todos; otra vez, los '
        'desmarca', (tester) async {
      await pump(tester, episodes: const {'s1': 4, 's2': 6, 's3': 9});
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_seasons',
      );
      await holdOk(tester);
      expect(check(season(1)), findsOneWidget);
      for (var n = 1; n <= 4; n++) {
        expect(check(episode(n)), findsOneWidget);
      }
      // Sigue en las temporadas: el OK mantenido no baja a los capítulos.
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_seasons',
      );

      await holdOk(tester);
      expect(check(season(1)), findsNothing);
      expect(check(episode(1)), findsNothing);
    });

    group('marcar a mano anota la serie en Seguir series', () {
      Future<String?> badge(WidgetTester tester) async {
        final items = await tester.runAsync(SeriesContinueService.items);
        if (items == null || items.isEmpty) return null;
        return HomeSeriesContinueCard.badgeOf(items.single);
      }

      testWidgets('un capítulo: sigue el próximo', (tester) async {
        await pump(tester);
        for (var i = 0; i < 2; i++) {
          await key(tester, LogicalKeyboardKey.arrowRight);
        }
        await holdOk(tester);
        expect(await badge(tester), 'Sigue: T1 · Cap. 4');
      });

      testWidgets('marcar uno anterior no vuelve atrás', (tester) async {
        await pump(tester);
        for (var i = 0; i < 4; i++) {
          await key(tester, LogicalKeyboardKey.arrowRight);
        }
        await holdOk(tester);
        for (var i = 0; i < 3; i++) {
          await key(tester, LogicalKeyboardKey.arrowLeft);
        }
        await holdOk(tester);
        expect(await badge(tester), 'Sigue: T1 · Cap. 6');
      });

      testWidgets('la temporada: sigue la próxima', (tester) async {
        await pump(tester, episodes: const {'s1': 4, 's2': 6, 's3': 9});
        await key(tester, LogicalKeyboardKey.arrowUp);
        await holdOk(tester);
        expect(await badge(tester), 'Sigue: T2 · Cap. 1');
      });

      testWidgets('desmarcar no anota', (tester) async {
        await pump(tester);
        await holdOk(tester);
        await tester.runAsync(SeriesContinueService.clear);
        await holdOk(tester);
        expect(await badge(tester), isNull);
      });
    });

    testWidgets('OK en un capítulo: ruedita en vez del número mientras pide '
        'el video', (tester) async {
      final stream = Completer<ResolvedPlayStream?>();
      await pump(tester, resolveEpisode: (_, _, _) => stream.future);
      await key(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        find.descendant(
          of: episode(1),
          matching: find.byKey(const ValueKey('episode_loading')),
        ),
        findsOneWidget,
      );
      // No se pudo: vuelve el número.
      stream.complete(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('episode_loading')), findsNothing);
      expect(
        find.descendant(of: episode(1), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('al abrir, si el sistema manda el foco a Atrás, vuelve a los '
        'capítulos; después de la primera tecla, no', (tester) async {
      await pump(tester);
      final back = FocusManager.instance.rootScope.descendants.firstWhere(
        (n) => n.debugLabel == 'series_detail_back',
      );
      // Como hace la pantalla al terminar de abrirse en el TV.
      back.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_episodes',
      );
      // Ya tocó una tecla: ir a Atrás es suyo.
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_back',
      );
    });

    testWidgets('abierto desde Seguir series: elegido el capítulo pedido', (
      tester,
    ) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: SeriesDetailScreen(
              series: MovieItem(contentId: 's2', name: 'Caballos lentos T2'),
              fetchSeason: (id) async => detail(
                asset(id: id, season: int.parse(id.substring(1)), episodes: 8),
              ),
              initialEpisodeId: 's2-e6',
              initialEpisodeNumber: 6,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<SeriesDetailScreenState>(
        find.byType(SeriesDetailScreen),
      );
      expect(state.debugSeasonId, 's2');
      expect(state.debugEpisodeIndex, 5);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_episodes',
      );
    });

    testWidgets('Marcar: ↑ desde las temporadas; marca y desmarca la serie', (
      tester,
    ) async {
      SeriesWatchlistService.instance.resetForTest();
      await pump(tester, episodes: const {'s1': 4, 's2': 6, 's3': 9});
      expect(find.text('Marcar'), findsOneWidget);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_watchlist',
      );
      await key(tester, LogicalKeyboardKey.enter);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Desmarcar'), findsOneWidget);
      final watchlist = SeriesWatchlistService.instance;
      expect(watchlist.items.single.name, 'Caballos lentos');
      // Se reconoce por cualquier temporada.
      expect(watchlist.contains(['s3']), isTrue);

      await key(tester, LogicalKeyboardKey.enter);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Marcar'), findsOneWidget);
      expect(watchlist.items, isEmpty);
      // ↓ vuelve a las temporadas.
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_seasons',
      );
    });

    testWidgets('con amigos: 👍 al lado de Marcar recomienda la serie', (
      tester,
    ) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final api = _SeriesVotesApi();
      final recommendations = SeriesRecommendationsProvider(
        api: api,
        isWatched: (_) async => false,
      );
      recommendations.setFriends(deviceId: 'yo', friends: const {'ana': 'Ana'});
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
            ChangeNotifierProvider.value(value: recommendations),
          ],
          child: MaterialApp(
            home: SeriesDetailScreen(
              series: MovieItem(contentId: 's2', name: 'Caballos lentos T2'),
              fetchSeason: (id) async => detail(
                asset(id: id, season: int.parse(id.substring(1)), episodes: 4),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // ↑ temporadas, ↑ Marcar, → 👍.
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowUp);
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'series_detail_vote_up',
      );
      await key(tester, LogicalKeyboardKey.enter);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      // La serie (su T1, la misma en todos los TV), sin nada visto: la T2.
      expect(api.sent.single['contentId'], 's1');
      expect(api.sent.single['name'], 'Caballos lentos');
      expect(api.sent.single[SeriesRecommendationsApi.seasonKey], 2);
      expect(recommendations.voteOf('s1'), MovieVote.up);
    });

    testWidgets('← desde la primera columna va a Atrás', (tester) async {
      await pump(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      final focused = FocusManager.instance.primaryFocus?.debugLabel;
      expect(focused, 'series_detail_back');
    });
  });
}

class _SeriesVotesApi extends MovieRecommendationsApi {
  final sent = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async =>
      const [];

  @override
  Future<void> recommendJson(
    String deviceId,
    Map<String, dynamic> json,
  ) async => sent.add(json);
}
