import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/tv_tab_bar.dart';

void main() {
  testWidgets('TvTabBar renders 3 tabs with outlined icons when unselected and full icons when selected',
      (tester) async {
    String selectedTab = 'explore';
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

    // 1. When 'explore' is selected:
    expect(find.byIcon(Icons.explore), findsOneWidget);
    expect(find.byIcon(Icons.search_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.bookmarks), findsNothing);

    // 2. Tap search tab to switch selection to 'search'
    await tester.tap(find.byIcon(Icons.search_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsNothing);
    expect(find.byIcon(Icons.search_outlined), findsNothing);
    expect(find.byIcon(Icons.bookmarks), findsNothing);

    // 3. Tap groups tab to switch selection to 'groups'
    await tester.tap(find.byIcon(Icons.bookmarks_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.bookmarks_outlined), findsNothing);
  });

  testWidgets('TvTabBar navigates between tabs using D-Pad arrow keys',
      (tester) async {
    String selectedTab = 'explore';
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
