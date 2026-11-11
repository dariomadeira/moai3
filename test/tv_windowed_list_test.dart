import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/theme/moai_icons.dart';

void main() {
  testWidgets(
    'TvWindowedList default showScrollDots is false and does not render dots',
    (tester) async {
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
                  return Focus(focusNode: node, child: Text(item));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<TvWindowedListState<String>>(
        find.byType(TvWindowedList<String>),
      );
      expect(state.pageCount, 2);
      expect(find.byType(AnimatedContainer), findsNothing);
    },
  );

  testWidgets(
    'TvWindowedList with showScrollDots=true renders dots and updates active dot on scroll',
    (tester) async {
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
                  return Focus(focusNode: node, child: Text(item));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<TvWindowedListState<String>>(
        find.byType(TvWindowedList<String>),
      );
      expect(state.pageCount, 2);
      expect(state.activeDotIndex, 0);

      // There should be 2 dots (AnimatedContainer)
      expect(find.byType(AnimatedContainer), findsNWidgets(2));

      // Move to item 4 (which is in page 2)
      state.ensureVisible(4);
      await tester.pumpAndSettle();

      expect(state.activeDotIndex, 1);
    },
  );

  testWidgets(
    'TvWindowedList with showScrollArrows=true renders pill arrows superimposed up and down',
    (tester) async {
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
                  return Focus(focusNode: node, child: Text(item));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<TvWindowedListState<String>>(
        find.byType(TvWindowedList<String>),
      );
      expect(state.effectiveIndicator, TvScrollIndicator.arrows);
      expect(state.canScrollUp, isFalse);
      expect(state.canScrollDown, isTrue);

      // At top: only down arrow is rendered
      expect(find.byIcon(MoaiIcons.chevronDown), findsOneWidget);
      expect(find.byIcon(MoaiIcons.chevronUp), findsNothing);

      // Move to item 2 (middle/anchor): scroll down
      state.ensureVisible(2);
      await tester.pumpAndSettle();

      // Now move towards the end (item 7)
      state.ensureVisible(7);
      await tester.pumpAndSettle();

      expect(state.canScrollUp, isTrue);
      expect(state.canScrollDown, isFalse);

      // At bottom: only up arrow is rendered
      expect(find.byIcon(MoaiIcons.chevronUp), findsOneWidget);
      expect(find.byIcon(MoaiIcons.chevronDown), findsNothing);
    },
  );

  testWidgets('row state stays with the item when the window shifts', (
    tester,
  ) async {
    final items = List.generate(8, (i) => 'Item $i');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              itemBuilder: (context, item, node, local, global, up, down) {
                return _Stamp(id: item);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = tester.state<_StampState>(
      find.byWidgetPredicate((w) => w is _Stamp && w.id == 'Item 2'),
    );
    final stamp = before.stamp;

    final state = tester.state<TvWindowedListState<String>>(
      find.byType(TvWindowedList<String>),
    );
    state.ensureVisible(3);
    await tester.pumpAndSettle();

    final after = tester.state<_StampState>(
      find.byWidgetPredicate((w) => w is _Stamp && w.id == 'Item 2'),
    );
    expect(after.stamp, stamp);
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets('un ítem de 2 lugares mide el doble y se mueve con los demás', (
    tester,
  ) async {
    final items = ['Grande', ...List.generate(5, (i) => 'Item $i')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              itemSpan: (item) => item == 'Grande' ? 2 : 1,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      down();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      up();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Arriba: el grande (2 lugares) y dos más.
    expect(
      tester.getSize(find.byKey(const ValueKey<int>(0))).height,
      closeTo(100, 0.01),
    );
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsNothing);

    Future<void> key(LogicalKeyboardKey k) async {
      await tester.sendKeyEvent(k);
      await tester.pumpAndSettle();
    }

    // ↓ hasta el último visible y uno más: la ventana corre y el grande sale.
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    await key(LogicalKeyboardKey.arrowDown);
    expect(find.text('Grande'), findsNothing);
    expect(find.text('Item 2'), findsOneWidget);

    // ↑ de vuelta hasta arriba: el grande vuelve con su foco.
    for (var i = 0; i < 4; i++) {
      await key(LogicalKeyboardKey.arrowUp);
    }
    expect(find.text('Grande'), findsOneWidget);
    final state = tester.state<TvWindowedListState<String>>(
      find.byType(TvWindowedList<String>),
    );
    expect(state.focusedGlobalIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '↑/↓ saltean los ítems que no toman el foco, que se siguen viendo',
    (tester) async {
      final items = ['Item 0', 'Info', 'Item 2', 'Item 3'];
      final focused = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: TvWindowedList<String>(
                items: items,
                windowSize: 4,
                itemExtent: 50,
                canFocus: (item) => item != 'Info',
                onFocusedGlobalIndex: (i) => focused.add(items[i]),
                itemBuilder: (context, item, node, local, global, up, down) {
                  return Focus(
                    focusNode: node,
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        down();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        up();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Text(item),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<TvWindowedListState<String>>(
        find.byType(TvWindowedList<String>),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(state.focusedGlobalIndex, 2);
      expect(find.text('Info'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(state.focusedGlobalIndex, 0);
      expect(focused, isNot(contains('Info')));

      // Pedir el que no toma el foco enfoca el siguiente.
      state.ensureVisible(1);
      await tester.pumpAndSettle();
      expect(state.focusedGlobalIndex, 2);
    },
  );

  group('packPages', () {
    // Los que empiezan con mayúscula ocupan dos lugares.
    int span(String item) => item == item.toUpperCase() ? 2 : 1;
    List<String> pack(List<String> items) =>
        TvWindowedList.packPages(items, pageSize: 4, span: span);

    test('si ya llenan las páginas, no cambia el orden', () {
      expect(pack(['H', 'a', 'b', 'C', 'd', 'e']), [
        'H',
        'a',
        'b',
        'C',
        'd',
        'e',
      ]);
    });

    test('adelanta un chico para llenar el lugar que queda', () {
      // a b c + (W no entra en 1) → d sube; W abre la página siguiente.
      expect(pack(['a', 'b', 'c', 'W', 'd']), ['a', 'b', 'c', 'd', 'W']);
    });

    test('sin chicos que adelantar, el último chico baja', () {
      // El caso del Inicio: clima, Descuentos, Amigos e Interesantes.
      expect(pack(['a', 'b', 'c', 'W']), ['a', 'b', 'W', 'c']);
    });

    test('sólo grandes: de a dos por página', () {
      expect(pack(['A', 'B', 'C']), ['A', 'B', 'C']);
    });
  });

  testWidgets('paged: ↓/↑ pasan de página entera y hay un punto por página', (
    tester,
  ) async {
    // Páginas de 4 lugares: [a, b, W] y [c].
    final items = ['a', 'b', 'W', 'c'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 4,
              itemExtent: 50,
              paged: true,
              showScrollDots: true,
              itemSpan: (item) => item == 'W' ? 2 : 1,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      down();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      up();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<TvWindowedListState<String>>(
      find.byType(TvWindowedList<String>),
    );
    expect(state.pageCount, 2);
    expect(find.text('c'), findsNothing);

    // a → b → W → (página 2) c, sola y arriba.
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(state.focusedGlobalIndex, 3);
    expect(state.activeDotIndex, 1);
    expect(find.text('a'), findsNothing);
    expect(tester.getTopLeft(find.text('c')).dy, lessThan(50));

    // ↑ vuelve a la página 1 entera, en W.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(state.focusedGlobalIndex, 2);
    expect(state.activeDotIndex, 0);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('ventana de dos: ↑ desde arriba de la ventana no se traba', (
    tester,
  ) async {
    final items = List.generate(5, (i) => 'Item $i');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: TvWindowedList<String>(
              items: items,
              windowSize: 2,
              itemExtent: 50,
              itemBuilder: (context, item, node, local, global, up, down) {
                return Focus(
                  focusNode: node,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      up();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      down();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Text(item),
                );
              },
            ),
          ),
        ),
      ),
    );
    final state = tester.state<TvWindowedListState<String>>(
      find.byType(TvWindowedList<String>),
    );
    state.ensureVisible(4);
    await tester.pumpAndSettle();

    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
    expect(focused(), 'win_4');
    for (final expected in ['win_3', 'win_2', 'win_1', 'win_0']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(focused(), expected);
      expect(find.text('Item ${expected.substring(4)}'), findsOneWidget);
    }
    for (final expected in ['win_1', 'win_2', 'win_3', 'win_4']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(focused(), expected);
    }
  });
}

class _Stamp extends StatefulWidget {
  final String id;

  const _Stamp({required this.id});

  @override
  State<_Stamp> createState() => _StampState();
}

class _StampState extends State<_Stamp> {
  static int _next = 0;
  late final int stamp = _next++;

  @override
  Widget build(BuildContext context) => Text(widget.id);
}
