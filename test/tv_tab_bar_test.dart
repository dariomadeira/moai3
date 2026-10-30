import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/features/home/widgets/tv_tab_bar.dart';

void main() {
  testWidgets('TvTabBar muestra 3 pestañas y sólo la elegida lleva su título',
      (tester) async {
    var selectedTab = TvTab.explore;
    final exploreFocusNode = FocusNode();
    final searchFocusNode = FocusNode();
    final groupsFocusNode = FocusNode();

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TvTabBar(
                selectedTab: selectedTab,
                onTabChanged: (newTab) {
                  setState(() => selectedTab = newTab);
                },
                exploreFocusNode: exploreFocusNode,
                searchFocusNode: searchFocusNode,
                groupsFocusNode: groupsFocusNode,
                onFocusDown: () {},
                onFocusLeft: () {},
                onFocusPlayer: () {},
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // La familia de íconos actual usa el mismo glifo elegida o no: la
    // pestaña elegida se reconoce por su título, que sólo ella muestra.
    void expectSelected(String title) {
      for (final t in const [
        'home_tab_explore',
        'home_tab_search',
        'home_tab_groups',
      ]) {
        expect(find.text(t), t == title ? findsOneWidget : findsNothing);
      }
    }

    // 1. Explorar elegida.
    expect(find.byIcon(MoaiIcons.tvTabExplorarSelected), findsOneWidget);
    expect(find.byIcon(MoaiIcons.tvTabBuscar), findsOneWidget);
    expect(find.byIcon(MoaiIcons.tvTabMarcadores), findsOneWidget);
    expectSelected('home_tab_explore');

    // 2. Buscar.
    await tester.tap(find.byIcon(MoaiIcons.tvTabBuscar));
    await tester.pumpAndSettle();
    expect(selectedTab, TvTab.search);
    expectSelected('home_tab_search');

    // 3. Marcadores.
    await tester.tap(find.byIcon(MoaiIcons.tvTabMarcadores));
    await tester.pumpAndSettle();
    expect(selectedTab, TvTab.groups);
    expectSelected('home_tab_groups');
  });

  testWidgets('TvTabBar navigates between tabs using D-Pad arrow keys',
      (tester) async {
    var selectedTab = TvTab.explore;
    final exploreFocusNode = FocusNode();
    final searchFocusNode = FocusNode();
    final groupsFocusNode = FocusNode();

    bool focusLeftCalled = false;
    bool focusDownCalled = false;
    bool focusPlayerCalled = false;

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TvTabBar(
                selectedTab: selectedTab,
                onTabChanged: (newTab) {
                  setState(() => selectedTab = newTab);
                },
                exploreFocusNode: exploreFocusNode,
                searchFocusNode: searchFocusNode,
                groupsFocusNode: groupsFocusNode,
                onFocusDown: () => focusDownCalled = true,
                onFocusLeft: () => focusLeftCalled = true,
                onFocusPlayer: () => focusPlayerCalled = true,
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Focus explore tab
    exploreFocusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(exploreFocusNode.hasFocus, isTrue);

    // Press Arrow Right -> focuses search tab
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(searchFocusNode.hasFocus, isTrue);

    // Press Arrow Right -> focuses groups tab
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(groupsFocusNode.hasFocus, isTrue);

    // Press Arrow Left -> focuses search tab
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(searchFocusNode.hasFocus, isTrue);

    // Press Arrow Left -> focuses explore tab
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(exploreFocusNode.hasFocus, isTrue);

    // Press Arrow Left from explore -> triggers onFocusLeft
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusLeftCalled, isTrue);

    // Press Arrow Down -> triggers onFocusDown
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focusDownCalled, isTrue);

    // Focus groups tab and press Arrow Right -> triggers onFocusPlayer
    groupsFocusNode.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focusPlayerCalled, isTrue);
  });
}
