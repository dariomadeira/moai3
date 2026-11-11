import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_watchlist_big_card.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/models/movie_models.dart';

import 'helpers/spanish_translations.dart';

List<MovieItem> _movies(int n) => [
  for (var i = 0; i < n; i++) MovieItem(contentId: 'm$i', name: 'Peli $i'),
];

void main() {
  /// La tarjeta como en el Chromecast: 960×540 a densidad 2, del ancho del
  /// panel y el alto de dos lugares del Inicio.
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<MovieItem> movies,
    int selectedIndex = 0,
  }) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.reset());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 780,
              height: 211,
              child: HomeWatchlistBigCard(
                movies: movies,
                selectedIndex: selectedIndex,
                isFocused: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('en el TV entran 2, con la imagen horizontal', (tester) async {
    await pumpCard(tester, movies: _movies(6));
    expect(find.byType(TvMovieCard), findsNWidgets(2));
    expect(
      tester
          .widgetList<TvMovieCard>(find.byType(TvMovieCard))
          .every((c) => c.wide),
      isTrue,
    );
    expect(find.text('Peli 0'), findsOneWidget);
    expect(find.text('Peli 2'), findsNothing);
    expect(find.text('Desmarcar todas'), findsOneWidget);
    expect(find.text('6 para ver'), findsOneWidget);
    // Hay más a la derecha: las flechas de los costados.
    expect(find.byType(HomeEdgePill), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('con una sola, queda a la izquierda (no centrada)', (
    tester,
  ) async {
    await pumpCard(tester, movies: _movies(1));
    final card = tester.getRect(find.byType(HomeWatchlistBigCard));
    final poster = tester.getRect(find.byType(TvMovieCard));
    // Arranca pegada al lugar de la flecha izquierda, en la mitad izquierda.
    expect(poster.center.dx, lessThan(card.center.dx));
  });

  testWidgets('se corre para que la elegida se vea', (tester) async {
    await pumpCard(tester, movies: _movies(6), selectedIndex: 5);
    expect(find.text('Peli 5'), findsOneWidget);
    expect(find.text('Peli 1'), findsNothing);
  });

  testWidgets('vacía: sin pósters ni "Quitar todas"', (tester) async {
    await pumpCard(tester, movies: const []);
    expect(find.byType(TvMovieCard), findsNothing);
    expect(find.text('Desmarcar todas'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
