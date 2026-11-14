import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_hero_side_posters.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/models/movie_models.dart';

import 'helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('←/→ pasan de póster, ← sale, OK abre y ↑/↓ salen', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final items = [
      MovieItem(contentId: 'a', name: 'Uno'),
      MovieItem(contentId: 'b', name: 'Dos'),
    ];
    final opened = <String>[];
    final exits = <String>[];
    const height = 220.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: height,
              width: HomeHeroSidePosters.widthFor(items.length, height),
              child: HomeHeroSidePosters(
                items: items,
                focusNode: focus,
                onOpen: (m) => opened.add(m.name),
                onExitLeft: () => exits.add('left'),
                onExitUp: () => exits.add('up'),
                onExitDown: () => exits.add('down'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final state = tester.state<HomeHeroSidePostersState>(
      find.byType(HomeHeroSidePosters),
    );
    bool selected(String name) => tester
        .widget<TvMovieCard>(find.widgetWithText(TvMovieCard, name))
        .isSelected!;

    // Sin foco, ninguno elegido.
    expect(selected('Uno'), isFalse);
    focus.requestFocus();
    await tester.pump();
    expect(selected('Uno'), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.debugIndex, 1);
    expect(selected('Dos'), isTrue);
    // Después del último no hay nada.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.debugIndex, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    expect(opened, ['Dos']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(state.debugIndex, 0);
    expect(exits, ['up', 'down']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(exits, ['up', 'down', 'left']);
  });
}
