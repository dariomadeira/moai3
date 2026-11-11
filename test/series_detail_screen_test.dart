import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/screens/series_detail_screen.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
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
    });

    Future<SeriesDetailScreenState> pump(
      WidgetTester tester, {
      int seasons = 3,
      Map<String, int> episodes = const {'s1': 30, 's2': 6, 's3': 9},
      Set<String> failing = const {},
      String open = 's1',
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
            child: MoaiGlassScope(
              child: SeriesDetailScreen(
                series: MovieItem(
                  contentId: open,
                  name: 'Caballos lentos T$number',
                  programType: 'teleplay',
                ),
                fetchSeason: fetch,
              ),
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

    testWidgets('con una sola temporada no hay lista', (tester) async {
      await pump(tester, seasons: 1);
      expect(season(1), findsNothing);
      expect(find.text('Temporadas'), findsNothing);
      expect(find.text('Capítulos'), findsOneWidget);
      // Sólo los puntos de los capítulos.
      expect(dots(tester, 'seasons'), isNull);
      expect(dots(tester), isNotNull);
      expect(find.textContaining('temporadas'), findsNothing);
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

    testWidgets('← desde la primera columna va a Atrás', (tester) async {
      await pump(tester);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      final focused = FocusManager.instance.primaryFocus?.debugLabel;
      expect(focused, 'series_detail_back');
    });
  });
}
