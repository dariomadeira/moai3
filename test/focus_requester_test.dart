import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/focus/focus_requester.dart';

void main() {
  testWidgets('un pedido más nuevo cancela al pendiente', (tester) async {
    final a = FocusNode(debugLabel: 'a');
    final b = FocusNode(debugLabel: 'b');
    final requester = FocusRequester(isMounted: () => true);
    var showA = false;
    late StateSetter setState;

    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, s) {
        setState = s;
        return Column(children: [
          if (showA) Focus(focusNode: a, child: const SizedBox(height: 10)),
          Focus(focusNode: b, child: const SizedBox(height: 10)),
        ]);
      }),
    ));

    // `a` todavía no existe: queda reintentando. Luego se pide `b`.
    requester.node(a);
    requester.node(b);
    await tester.pump();
    expect(b.hasFocus, isTrue);

    // Aunque `a` aparezca después, el pedido viejo ya no debe robar el foco.
    setState(() => showA = true);
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(b.hasFocus, isTrue);
    expect(a.hasFocus, isFalse);

    a.dispose();
    b.dispose();
  });

  testWidgets('immediate enfoca en el acto si el nodo existe', (tester) async {
    final node = FocusNode();
    await tester.pumpWidget(
      MaterialApp(home: Focus(focusNode: node, child: const SizedBox())),
    );
    FocusRequester(isMounted: () => true).node(node, immediate: true);
    await tester.idle();
    expect(node.hasFocus, isTrue);
    node.dispose();
  });

  testWidgets('espera a que el destino se monte', (tester) async {
    final node = FocusNode();
    var visible = false;
    late StateSetter setState;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, s) {
        setState = s;
        return visible
            ? Focus(focusNode: node, child: const SizedBox())
            : const SizedBox();
      }),
    ));

    FocusRequester(isMounted: () => true).node(node);
    await tester.pump();
    expect(node.hasFocus, isFalse);

    setState(() => visible = true);
    await tester.pump();
    await tester.pump();
    expect(node.hasFocus, isTrue);
    node.dispose();
  });
}
