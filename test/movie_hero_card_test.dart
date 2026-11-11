import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/widgets/movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';
import 'package:moai3/widgets/tv_common/moai_glass_pill.dart';

import 'helpers/real_fonts.dart';
import 'helpers/spanish_translations.dart';

MovieItem movie(int i) => MovieItem(
  contentId: 'm$i',
  name: 'Película número $i con un título largo para probar el corte',
  description: 'Una sinopsis bastante larga ' * 8,
  tags: 'Action,Adventure,Comedy',
  programType: 'movie',
);

void main() {
  setUpAll(loadRealFonts);

  late List<String> calls;
  late Set<String> interesting;
  late int exitedLeft;

  Future<MovieHeroCardState> pump(
    WidgetTester tester, {
    int count = 3,
    double width = 560,
  }) async {
    useSpanishTranslations();
    calls = [];
    interesting = {};
    exitedLeft = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              height: width / MovieHeroCard.aspectRatio,
              child: StatefulBuilder(
                builder: (context, setState) => MovieHeroCard(
                  movies: [for (var i = 0; i < count; i++) movie(i)],
                  focusNode: focus,
                  onPlay: (m) => calls.add('play ${m.contentId}'),
                  onOpen: (m) => calls.add('open ${m.contentId}'),
                  onToggleInteresting: (m) => setState(() {
                    calls.add('interesting ${m.contentId}');
                    if (!interesting.remove(m.contentId)) {
                      interesting.add(m.contentId);
                    }
                  }),
                  isInteresting: (m) => interesting.contains(m.contentId),
                  onExitLeft: () => exitedLeft++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    return tester.state<MovieHeroCardState>(find.byType(MovieHeroCard));
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }

  bool isSelected(WidgetTester tester, MovieHeroAction action) => tester
      .widget<MoaiPillButton>(find.byKey(ValueKey('movie_hero_${action.name}')))
      .selected;

  testWidgets('arranca en Reproducir; ←/→ recorren los botones', (
    tester,
  ) async {
    final hero = await pump(tester);
    expect(hero.debugAction, MovieHeroAction.play);
    expect(isSelected(tester, MovieHeroAction.play), isTrue);

    for (final expected in [
      MovieHeroAction.interesting,
      MovieHeroAction.more,
      MovieHeroAction.previous,
      MovieHeroAction.next,
    ]) {
      await key(tester, LogicalKeyboardKey.arrowRight);
      expect(hero.debugAction, expected);
    }
    // En el último no sigue.
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(hero.debugAction, MovieHeroAction.next);
  });

  testWidgets('← desde el primero sale por la izquierda', (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(exitedLeft, 1);
  });

  testWidgets('OK hace la acción de cada botón', (tester) async {
    await pump(tester);
    await key(tester, LogicalKeyboardKey.select);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.select);
    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.select);
    expect(calls, ['play m0', 'interesting m0', 'open m0']);
    // El botón de Interesante refleja el estado.
    expect(find.text('Desmarcar'), findsOneWidget);
  });

  testWidgets('las flechas pasan de película y dan la vuelta', (tester) async {
    final hero = await pump(tester);
    for (var i = 0; i < 4; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(hero.debugAction, MovieHeroAction.next);
    await key(tester, LogicalKeyboardKey.select);
    expect(hero.debugMovieIndex, 1);
    await key(tester, LogicalKeyboardKey.select);
    await key(tester, LogicalKeyboardKey.select);
    expect(hero.debugMovieIndex, 0);
    // El foco se queda en la flecha.
    expect(hero.debugAction, MovieHeroAction.next);

    await key(tester, LogicalKeyboardKey.arrowLeft);
    await key(tester, LogicalKeyboardKey.select);
    expect(hero.debugMovieIndex, 2);
  });

  testWidgets('con una sola película no hay flechas', (tester) async {
    final hero = await pump(tester, count: 1);
    expect(find.byKey(const ValueKey('movie_hero_previous')), findsNothing);
    for (var i = 0; i < 5; i++) {
      await key(tester, LogicalKeyboardKey.arrowRight);
    }
    expect(hero.debugAction, MovieHeroAction.more);
  });

  testWidgets('botones y flechas: mismo alto y misma separación, sin géneros', (
    tester,
  ) async {
    // Tamaño real en el Chromecast (2/3 del panel).
    await pump(tester, width: 548);
    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));
    final play = rect('movie_hero_play');
    final interesting = rect('movie_hero_interesting');
    final more = rect('movie_hero_more');
    final prev = rect('movie_hero_previous');
    final next = rect('movie_hero_next');
    // Sin achicarse: todos del mismo alto que las flechas.
    for (final r in [play, interesting, more]) {
      expect(r.height, closeTo(prev.height, 0.01));
    }
    expect(interesting.left - play.right, closeTo(10, 0.01));
    expect(more.left - interesting.right, closeTo(10, 0.01));
    expect(next.left - prev.right, closeTo(10, 0.01));
    // Sin etiquetas de géneros arriba del título.
    expect(find.byType(MoaiGlassPill), findsNothing);
  });

  testWidgets('textos largos no desbordan, ni en una tarjeta chica', (
    tester,
  ) async {
    for (final width in [480.0, 560.0, 900.0, 1200.0]) {
      await pump(tester, width: width);
      expect(tester.takeException(), isNull, reason: 'ancho $width');
    }
  });
}
