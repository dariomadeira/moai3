import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/lists/tv_windowed_row.dart';

void main() {
  Future<TvWindowedRowState<String>> pumpRow(
    WidgetTester tester, {
    required int count,
    required int selected,
  }) async {
    final items = List.generate(count, (i) => 'E$i');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 120,
            child: TvWindowedRow<String>(
              items: items,
              selectedIndex: selected,
              windowSize: 5,
              itemBuilder: (context, item, index, isSelected) =>
                  Text(isSelected ? '[$item]' : item),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state<TvWindowedRowState<String>>(
      find.byType(TvWindowedRow<String>),
    );
  }

  testWidgets('muestra 5 del mismo ancho y se corre dejando ver el siguiente', (
    tester,
  ) async {
    var state = await pumpRow(tester, count: 8, selected: 0);
    expect(state.windowStart, 0);
    expect(find.text('[E0]'), findsOneWidget);
    expect(find.text('E4'), findsOneWidget);
    expect(find.text('E5'), findsNothing);
    expect(
      tester.getSize(find.text('[E0]')).width,
      lessThanOrEqualTo(tester.getSize(find.byType(Expanded).first).width),
    );

    // Hasta el cuarto no se mueve; en el quinto, sí (se ve el sexto).
    state = await pumpRow(tester, count: 8, selected: 3);
    expect(state.windowStart, 0);
    state = await pumpRow(tester, count: 8, selected: 4);
    expect(state.windowStart, 1);
    expect(find.text('E5'), findsOneWidget);

    // Al final no deja huecos.
    state = await pumpRow(tester, count: 8, selected: 7);
    expect(state.windowStart, 3);
    expect(find.text('[E7]'), findsOneWidget);

    // Volviendo, deja ver el anterior.
    state = await pumpRow(tester, count: 8, selected: 3);
    expect(state.windowStart, 2);
  });

  testWidgets('puntos abajo sólo si hay más de los que entran', (tester) async {
    var state = await pumpRow(tester, count: 4, selected: 0);
    expect(state.pageCount, 1);
    expect(find.byType(AnimatedContainer), findsNothing);

    state = await pumpRow(tester, count: 12, selected: 0);
    expect(state.pageCount, 3);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
    expect(state.activeDotIndex, 0);

    state = await pumpRow(tester, count: 12, selected: 6);
    expect(state.activeDotIndex, 1);
    // Los puntos van debajo de la fila.
    expect(
      tester.getTopLeft(find.byType(AnimatedContainer).first).dy,
      greaterThan(tester.getBottomLeft(find.text('[E6]')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
