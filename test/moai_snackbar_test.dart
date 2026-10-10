import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

void main() {
  testWidgets('MoaiSnackBar construye un snackbar estilo pill con sombra',
      (tester) async {
    final snackBar = MoaiSnackBar.buildSnackBar(
      context: null,
      message: 'Test message',
      icon: AppIcons.check,
    );

    expect(snackBar.elevation, equals(0));
    expect(snackBar.backgroundColor, equals(Colors.transparent));
    expect(snackBar.behavior, equals(SnackBarBehavior.floating));
    expect(snackBar.shape, isA<RoundedRectangleBorder>());
    expect(snackBar.content, isNotNull);
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
    expect(find.byType(AppIcon), findsOneWidget);
  });

  testWidgets(
      'MoaiSnackBar.showSuccess usa el color del theme (onPrimary) y no colores hardcodeados',
      (tester) async {
    const customOnPrimary = Color(0xFF123456);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(onPrimary: customOnPrimary),
        ),
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

    final iconWidget = tester.widget<AppIcon>(find.byType(AppIcon));
    expect(iconWidget.color, equals(customOnPrimary));
  });
}

