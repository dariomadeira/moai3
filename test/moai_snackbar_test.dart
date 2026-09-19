import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

void main() {
  testWidgets('MoaiSnackBar construye un snackbar estilo pill sin sombras',
      (tester) async {
    final snackBar = MoaiSnackBar.buildSnackBar(
      context: null,
      message: 'Test message',
      icon: Icons.check_circle_outline,
    );

    expect(snackBar.elevation, equals(0));
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.shape, isA<StadiumBorder>());
  });

  testWidgets('MoaiSnackBar.show muestra el mensaje y el icono en pantalla',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                MoaiSnackBar.showSuccess(context, message: 'Operación exitosa');
              },
              child: const Text('Mostrar'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mostrar'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Operación exitosa'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}

