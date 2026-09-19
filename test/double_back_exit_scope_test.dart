import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/double_back_exit_scope.dart';

void main() {
  testWidgets('back interceptado no cuenta para salir', (tester) async {
    var isFullScreen = true;

    await tester.pumpWidget(
      MaterialApp(
        home: DoubleBackExitScope(
          onBackIntercept: () {
            if (isFullScreen) {
              isFullScreen = false;
              return true;
            }
            return false;
          },
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(isFullScreen, isFalse);
    expect(find.byType(SnackBar), findsNothing);

    // Debounce usa DateTime.now() (reloj real), no el fake async del tester.
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('primer back muestra SnackBar de doble salida', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DoubleBackExitScope(
          child: Scaffold(body: SizedBox()),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}

