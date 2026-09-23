import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

void main() {
  testWidgets('TvWindowedList default showScrollDots is false and does not render dots', (tester) async {
    final items = List.generate(8, (i) => 'Item $i');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<TvWindowedListState<String>>(find.byType(TvWindowedList<String>));
    expect(state.pageCount, 2);
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('TvWindowedList with showScrollDots=true renders dots and updates active dot on scroll', (tester) async {
    final items = List.generate(8, (i) => 'Item $i');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              showScrollDots: true,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<TvWindowedListState<String>>(find.byType(TvWindowedList<String>));
    expect(state.pageCount, 2);
    expect(state.activeDotIndex, 0);

    // There should be 2 dots (AnimatedContainer)
    expect(find.byType(AnimatedContainer), findsNWidgets(2));

    // Move to item 4 (which is in page 2)
    state.ensureVisible(4);
    await tester.pumpAndSettle();

    expect(state.activeDotIndex, 1);
  });

  testWidgets('TvWindowedList with showScrollArrows=true renders pill arrows superimposed up and down', (tester) async {
    final items = List.generate(8, (i) => 'Item $i');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              showScrollArrows: true,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state<TvWindowedListState<String>>(find.byType(TvWindowedList<String>));
    expect(state.effectiveIndicator, TvScrollIndicator.arrows);
    expect(state.canScrollUp, isFalse);
    expect(state.canScrollDown, isTrue);

    // At top: only down arrow is rendered
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);

    // Move to item 2 (middle/anchor): scroll down
    state.ensureVisible(2);
    await tester.pumpAndSettle();

    // Now move towards the end (item 7)
    state.ensureVisible(7);
    await tester.pumpAndSettle();

    expect(state.canScrollUp, isTrue);
    expect(state.canScrollDown, isFalse);

    // At bottom: only up arrow is rendered
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });
}
