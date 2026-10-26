import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_arcade_card.dart';

import 'helpers/spanish_translations.dart';

void main() {
  /// La tarjeta como en el Chromecast: 960×540 a densidad 2, del ancho del
  /// panel y la altura de una de las 4 tarjetas del Inicio.
  Future<void> pumpCard(
    WidgetTester tester, {
    required bool canInvite,
    HomeArcadeAction selected = HomeArcadeAction.start,
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
              width: 810,
              height: 99,
              child: HomeArcadeCard(
                romName: 'Marvel vs. Capcom: Clash of Super Heroes',
                details: 'Capcom  ·  1998',
                canInvite: canInvite,
                selectedAction: selected,
                isFocused: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sin amigos conectados no ofrece invitar', (tester) async {
    await pumpCard(tester, canInvite: false);
    expect(find.text('Jugar'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.text('Invitar'), findsNothing);
  });

  testWidgets('con amigos conectados ofrece invitar y entra todo', (
    tester,
  ) async {
    await pumpCard(tester, canInvite: true, selected: HomeArcadeAction.invite);
    expect(find.text('Invitar'), findsOneWidget);
    // Tres botones y un nombre largo: un desborde haría fallar el test.
    expect(tester.takeException(), isNull);
  });
}
