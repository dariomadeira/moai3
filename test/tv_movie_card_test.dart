import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/widgets/tv_common/moai_filled_star.dart';

void main() {
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

  final star = find.byKey(const ValueKey('movie_card_well_rated'));

  testWidgets('sólo las de más de 7 llevan la estrella', (tester) async {
    for (final (score, expected) in [
      ('8.5', findsOneWidget),
      ('7.1', findsOneWidget),
      ('7.0', findsNothing),
      ('6.2', findsNothing),
      ('0', findsNothing),
      (null, findsNothing),
      ('', findsNothing),
    ]) {
      await tester.pumpWidget(card(score));
      expect(star, expected, reason: 'puntaje $score');
    }
  });

  testWidgets('la estrella no cambia el tamaño del póster ni del título', (
    tester,
  ) async {
    await tester.pumpWidget(card('6.0'));
    final posterWithout = tester.getSize(find.byType(Stack).first);
    final titleWithout = tester.getSize(find.byType(Text)).height;

    await tester.pumpWidget(card('8.0'));
    expect(star, findsOneWidget);
    expect(tester.getSize(find.byType(Stack).first), posterWithout);
    expect(tester.getSize(find.byType(Text)).height, titleWithout);
    // El título se corta antes, no se desborda.
    expect(tester.takeException(), isNull);
  });

  testWidgets('en tema claro la estrella usa el dorado oscuro', (tester) async {
    await tester.pumpWidget(card('8.0', brightness: Brightness.light));
    expect(tester.widget<MoaiFilledStar>(star).color, const Color(0xFFB45309));
    // MaterialApp anima el cambio de tema: se espera a que termine.
    await tester.pumpWidget(card('8.0'));
    await tester.pumpAndSettle();
    expect(tester.widget<MoaiFilledStar>(star).color, const Color(0xFFFBBF24));
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
