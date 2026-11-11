import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/real_fonts.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/models/movie_models.dart';

void main() {
  setUpAll(loadRealFonts);
  Widget card(String? score, {Brightness brightness = Brightness.dark}) =>
      MaterialApp(
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 290,
              child: TvMovieCard(
                key: ValueKey(score),
                movie: MovieItem(
                  contentId: 'id_$score',
                  name: 'Una película con un título bastante largo',
                  score: score,
                ),
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

  testWidgets('no lleva estrella y el nombre largo se corta', (tester) async {
    await tester.pumpWidget(card('8.5'));
    expect(find.byKey(const ValueKey('movie_card_well_rated')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('con progreso lleva la barra de lo visto; sin él, no', (
    tester,
  ) async {
    Widget wide(double? progress) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 220,
          height: TvMovieCard.heightForWidth(220, wide: true),
          child: TvMovieCard(
            movie: MovieItem(contentId: 'p', name: 'Coco'),
            isSelected: false,
            wide: true,
            progress: progress,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(wide(null));
    expect(find.byType(FractionallySizedBox), findsNothing);
    await tester.pumpWidget(wide(0.42));
    final bar = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(bar.widthFactor, 0.42);
    expect(tester.takeException(), isNull);
  });

  test('isWellRated: umbral "más de 7"', () {
    bool rated(String? s) =>
        MovieItem(contentId: '1', name: 'x', score: s).isWellRated;
    expect(rated('7.01'), isTrue);
    expect(rated(' 9 '), isTrue);
    expect(rated('7'), isFalse);
    expect(rated('abc'), isFalse);
    expect(rated(null), isFalse);
  });
}
