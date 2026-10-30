import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/screens/movie_category_screen.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

List<MovieItem> movies(int from, int to) => [
  for (var i = from; i <= to; i++)
    MovieItem(contentId: 'm$i', name: 'Película $i', programType: 'movie'),
];

void main() {
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  final category = CategoryColumn(
    columnId: 76275,
    columnName: 'Acción',
    hasMore: true,
  );

  Future<MovieCategoryScreenState> pump(
    WidgetTester tester, {
    ({List<MovieItem> movies, int pages, bool ended})? initial,
    required CategoryPageFetcher fetchPage,
    Future<int?> Function()? fetchTotal,
  }) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => TvSettingsProvider(prefs),
          child: MovieCategoryScreen(
            category: category,
            initial: initial,
            fetchPage: fetchPage,
            fetchTotal: fetchTotal,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return tester.state<MovieCategoryScreenState>(
      find.byType(MovieCategoryScreen),
    );
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }

  testWidgets('el título muestra cuántas tiene la categoría', (tester) async {
    await pump(
      tester,
      initial: (movies: movies(1, 10), pages: 1, ended: true),
      fetchPage: (_) async => null,
      fetchTotal: () async => 5942,
    );
    await tester.pump();
    expect(find.text('5.942 películas'), findsOneWidget);
  });

  testWidgets('sin total, el título queda sin número', (tester) async {
    await pump(
      tester,
      initial: (movies: movies(1, 10), pages: 1, ended: true),
      fetchPage: (_) async => null,
      fetchTotal: () async => null,
    );
    await tester.pump();
    expect(find.textContaining('películas'), findsNothing);
  });

  testWidgets('arranca con lo que ya bajó la grilla, sin pedir de nuevo', (
    tester,
  ) async {
    final asked = <int>[];
    final screen = await pump(
      tester,
      initial: (movies: movies(1, 30), pages: 1, ended: false),
      fetchPage: (page) async {
        asked.add(page);
        return null;
      },
    );
    expect(screen.debugLoaded, 30);
    expect(asked, isEmpty);
    expect(find.text('Acción'), findsOneWidget);
    expect(find.byType(TvMovieCard), findsWidgets);
  });

  testWidgets(
    'al acercarse al final pide la página siguiente sin mover el foco',
    (tester) async {
      final asked = <int>[];
      final next = Completer<List<MovieItem>?>();
      final screen = await pump(
        tester,
        initial: (movies: movies(1, 30), pages: 1, ended: false),
        fetchPage: (page) {
          asked.add(page);
          return next.future;
        },
      );

      // 30 películas = 6 filas: bajar hasta la 4.ª (a 2 del final) pide más.
      for (var i = 0; i < 3; i++) {
        await key(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(screen.debugIndex, 15);
      expect(asked, [2]);

      next.complete(movies(31, 60));
      await tester.pump();
      await tester.pump();
      expect(screen.debugLoaded, 60);
      expect(screen.debugIndex, 15);

      // No pide dos veces la misma página mientras carga ni después.
      await key(tester, LogicalKeyboardKey.arrowDown);
      expect(asked, [2]);
    },
  );

  testWidgets('sin nada guardado pide la página 1; si viene corta, terminó', (
    tester,
  ) async {
    final asked = <int>[];
    final screen = await pump(
      tester,
      fetchPage: (page) async {
        asked.add(page);
        return movies(1, 12);
      },
    );
    await tester.pump();
    expect(asked, [1]);
    expect(screen.debugLoaded, 12);

    // A la 4.ª columna (índice 3).
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    // 12 = 3 filas; bajar hasta el final no pide más (vino corta).
    for (var i = 0; i < 4; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(asked, [1]);
    // La última fila tiene 2 (10 y 11): ↓ desde la 4.ª columna (8) va a la
    // última película.
    expect(screen.debugIndex, 11);
  });

  testWidgets('si falla la primera página, avisa y OK reintenta', (
    tester,
  ) async {
    var calls = 0;
    final screen = await pump(
      tester,
      fetchPage: (page) async {
        calls++;
        return calls == 1 ? null : movies(1, 5);
      },
    );
    await tester.pump();
    expect(find.byType(TvEmptyStateCard), findsOneWidget);

    await key(tester, LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(screen.debugLoaded, 5);
    expect(find.byType(TvEmptyStateCard), findsNothing);
  });

  testWidgets('← desde la primera columna va a Volver', (tester) async {
    await pump(
      tester,
      initial: (movies: movies(1, 10), pages: 1, ended: true),
      fetchPage: (_) async => null,
    );
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'movie_category_grid',
    );
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'movie_category_back',
    );
  });

  testWidgets('las repetidas entre páginas no se duplican', (tester) async {
    final screen = await pump(
      tester,
      initial: (movies: movies(1, 30), pages: 1, ended: false),
      fetchPage: (_) async => [...movies(25, 30), ...movies(31, 40)],
    );
    for (var i = 0; i < 3; i++) {
      await key(tester, LogicalKeyboardKey.arrowDown);
    }
    await tester.pump();
    expect(screen.debugLoaded, 40);
  });
}
