import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

void main() {
  testWidgets('MoaiSnackBar construye un snackbar estilo pill con sombra',
      (tester) async {
    final snackBar = MoaiSnackBar.buildSnackBar(
      context: null,
      message: 'Test message',
      icon: Icons.check_circle_outline,
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
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
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

    final iconWidget =
        tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
    expect(iconWidget.color, equals(customOnPrimary));
  });

  group('onDismiss solo ante un descarte real (SPEC-50 §2.3)', () {
    late BuildContext ctx;
    late int dismissed;

    Future<void> pumpHost(WidgetTester tester) async {
      dismissed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            }),
          ),
        ),
      );
    }

    void showInvite() => MoaiSnackBar.show(
          ctx,
          message: 'Invitación',
          onAction: () {},
          onDismiss: () => dismissed++,
          duration: const Duration(seconds: 25),
        );

    testWidgets('atrás con el snack enfocado lo descarta', (tester) async {
      await pumpHost(tester);
      showInvite();
      await tester.pumpAndSettle();

      // goBack no tiene tecla física en el simulador; escape usa la misma rama.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(dismissed, 1);
    });

    testWidgets('otro snack encima no lo descarta', (tester) async {
      await pumpHost(tester);
      showInvite();
      await tester.pumpAndSettle();

      MoaiSnackBar.showInfo(ctx, message: 'Otro aviso');
      await tester.pumpAndSettle();

      expect(dismissed, 0);
    });

    testWidgets('al vencer el tiempo se descarta', (tester) async {
      await pumpHost(tester);
      showInvite();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 26));
      await tester.pumpAndSettle();

      expect(dismissed, 1);
    });
  });
}
