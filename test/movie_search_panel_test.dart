import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
import 'package:moai3/features/movies/widgets/movie_poster_grid.dart';
import 'package:moai3/features/movies/widgets/movie_search_panel.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// [n] películas para la página [page] de [query] (ids únicos).
List<MovieItem> page(String query, int page, int n) => [
  for (var i = 0; i < n; i++)
    MovieItem(
      contentId: '$query-$page-$i',
      name: '$query $page-$i',
      programType: 'movie',
    ),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<(String, int)> calls;
  late List<MovieItem> opened;
  late int exitedLeft;
  late FocusNode field;

  Future<MovieSearchController> pump(
    WidgetTester tester, {
    int total = 20,
    double width = 1400,
    Map<String, Object> prefs = const {},
  }) async {
    useSpanishTranslations();
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    calls = [];
    opened = [];
    exitedLeft = 0;
    field = FocusNode(debugLabel: 'field');
    final clear = FocusNode(debugLabel: 'clear');
    addTearDown(field.dispose);
    addTearDown(clear.dispose);
    final controller = MovieSearchController(
      fetch: (query, p) async {
        calls.add((query, p));
        final n = (total - (p - 1) * MovieSearchPage.pageSize).clamp(
          0,
          MovieSearchPage.pageSize,
        );
        return MovieSearchPage(items: page(query, p, n), total: total);
      },
      localMovies: () => const [],
    );
    addTearDown(controller.dispose);
    await controller.loadHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: 900,
            child: MovieSearchPanel(
              controller: controller,
              fieldFocusNode: field,
              clearFocusNode: clear,
              onExitLeft: () => exitedLeft++,
              onOpenMovie: opened.add,
            ),
          ),
        ),
      ),
    );
    field.requestFocus();
    await tester.pump();
    return controller;
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  int selected(WidgetTester tester) =>
      tester.state<MoviePosterGridState>(find.byType(MoviePosterGrid)).index;

  testWidgets('↓ del campo a los resultados, ↑ de la primera fila al campo', (
    tester,
  ) async {
    final c = await pump(tester);
    await c.submit('batman');
    await tester.pump();

    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'movie_search_results');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(selected(tester), 1);
    await key(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), 'field');
  });

  testWidgets('← desde la primera columna sale; OK abre la película', (
    tester,
  ) async {
    final c = await pump(tester);
    await c.submit('batman');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowDown);

    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.select);
    expect(opened.single.contentId, 'batman-1-5');

    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(exitedLeft, 1);
  });

  testWidgets('al acercarse al final pide la página siguiente', (tester) async {
    final c = await pump(tester, total: 60);
    await c.submit('batman');
    await tester.pump();
    // 3 páginas automáticas sólo si quedan pocas: acá la 1 alcanza (20).
    expect(calls, [('batman', 1)]);

    await key(tester, LogicalKeyboardKey.arrowDown);
    // 20 = 4 filas; en la 2.ª quedan 2 debajo: pide la página 2.
    await key(tester, LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(calls.last, ('batman', 2));
    expect(c.results.length, 40);
    expect(selected(tester), 5);
  });

  testWidgets('una búsqueda nueva vuelve la selección al principio', (
    tester,
  ) async {
    final c = await pump(tester);
    await c.submit('batman');
    await tester.pump();
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(selected(tester), 6);

    await c.submit('superman');
    await tester.pump();
    expect(selected(tester), 0);
  });

  testWidgets('con el campo vacío, ↓ va a las recientes y OK las repite', (
    tester,
  ) async {
    final c = await pump(
      tester,
      prefs: {
        'movie_search_history': ['rocky', 'alien'],
      },
    );
    await tester.pump();
    expect(find.text('rocky'), findsOneWidget);

    // Una al lado de la otra: ↓ a la primera, → a la segunda.
    await key(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), 'movie_search_recent_0');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'movie_search_recent_1');
    expect(
      tester.getCenter(find.text('rocky')).dy,
      tester.getCenter(find.text('alien')).dy,
    );
    await key(tester, LogicalKeyboardKey.select);
    await tester.pump();
    expect(c.query, 'alien');
    expect(calls, [('alien', 1)]);
    expect(focused(), 'field');
  });

  testWidgets('"Borrar búsquedas" vacía las recientes', (tester) async {
    final c = await pump(
      tester,
      prefs: {
        'movie_search_history': ['rocky', 'alien'],
      },
    );
    await tester.pump();
    expect(find.text('Borrar búsquedas'), findsOneWidget);

    await key(tester, LogicalKeyboardKey.arrowDown);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'movie_search_recent_2');
    await key(tester, LogicalKeyboardKey.select);
    await tester.pump();

    expect(c.history, isEmpty);
    expect(find.text('rocky'), findsNothing);
    expect(find.text('Borrar búsquedas'), findsNothing);
    expect(find.text('Buscá por título, actor o director'), findsOneWidget);
    expect(focused(), 'field');
    // Quedó borrado también lo guardado.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('movie_search_history'), isNull);
  });

  testWidgets(
    'si no entran pasan abajo: ↓/↑ entre filas, ← al principio sale',
    (tester) async {
      await pump(
        tester,
        width: 520,
        prefs: {
          'movie_search_history': [
            'el señor de los anillos',
            'harry potter y la piedra filosofal',
            'volver al futuro',
            'rocky',
          ],
        },
      );
      await tester.pump();
      final rows = {
        for (final t in ['el señor de los anillos', 'volver al futuro'])
          tester.getCenter(find.text(t)).dy,
      };
      expect(rows.length, 2, reason: 'no entran en una sola fila');

      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'movie_search_recent_0');
      await key(tester, LogicalKeyboardKey.arrowDown);
      final second = focused();
      expect(second, isNot('movie_search_recent_0'));
      expect(second, startsWith('movie_search_recent_'));
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'movie_search_recent_0');
      // ↑ desde la primera fila vuelve al campo.
      await key(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'field');

      // ← al principio de una fila sale a la grilla.
      await key(tester, LogicalKeyboardKey.arrowDown);
      await key(tester, LogicalKeyboardKey.arrowLeft);
      expect(exitedLeft, 1);
    },
  );
}
