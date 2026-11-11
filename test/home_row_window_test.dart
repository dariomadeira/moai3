import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';

void main() {
  testWidgets('sólo se corre cuando la elegida sale por un costado', (
    tester,
  ) async {
    late int start;
    Future<void> select(int i) => tester.pumpWidget(
      HomeRowWindow(
        count: 6,
        visible: 3,
        selected: i,
        builder: (s) {
          start = s;
          return const SizedBox();
        },
      ),
    );

    await select(0);
    expect(start, 0);
    await select(2);
    expect(start, 0);
    // Sale por la derecha: se corre de a una.
    await select(3);
    expect(start, 1);
    await select(5);
    expect(start, 3);
    // Volviendo en el medio la fila no se mueve.
    await select(4);
    expect(start, 3);
    await select(3);
    expect(start, 3);
    // Sale por la izquierda.
    await select(2);
    expect(start, 2);
    // Fuera de la lista (un botón, sin foco): queda donde está.
    await select(-1);
    expect(start, 2);
  });
}
