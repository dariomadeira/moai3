import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

void main() {
  setUp(() {
    ModalRouteTracker.instance.resetForTesting();
  });

  group('ModalRouteTracker Unit & Widget Tests', () {
    test('inicia sin modales activos', () {
      expect(ModalRouteTracker.instance.hasActiveModal, isFalse);
      expect(ModalRouteTracker.instance.activeModalCount, equals(0));
    });

    test('pause y resume manual cambian el estado y notifican listeners', () {
      final tracker = ModalRouteTracker.instance;
      int notifications = 0;
      tracker.addListener(() => notifications++);

      tracker.pause();
      expect(tracker.hasActiveModal, isTrue);
      expect(notifications, equals(1));

      // Pausa anidada
      tracker.pause();
      expect(tracker.hasActiveModal, isTrue);

      tracker.resume();
      expect(tracker.hasActiveModal, isTrue);

      tracker.resume();
      expect(tracker.hasActiveModal, isFalse);
      expect(notifications, equals(2));
    });

    testWidgets('didPush y didPop de diálogo modal actualizan hasActiveModal',
        (tester) async {
      final tracker = ModalRouteTracker.instance;
      bool? lastModalState;
      tracker.addListener(() {
        lastModalState = tracker.hasActiveModal;
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [tracker],
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showGeneralDialog<void>(
                    context: ctx,
                    pageBuilder: (c, _, _) => const Text('DialogContent'),
                  );
                },
                child: const Text('OpenDialog'),
              ),
            ),
          ),
        ),
      );

      expect(tracker.hasActiveModal, isFalse);

      // Abrir modal
      await tester.tap(find.text('OpenDialog'));
      await tester.pumpAndSettle();

      expect(tracker.hasActiveModal, isTrue);
      expect(lastModalState, isTrue);
      expect(find.text('DialogContent'), findsOneWidget);

      // Cerrar modal
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pop();
      await tester.pumpAndSettle();

      expect(tracker.hasActiveModal, isFalse);
      expect(lastModalState, isFalse);
    });

    testWidgets(
        'MoaiSnackBar con onAction NO roba el foco si hasActiveModal es true',
        (tester) async {
      ModalRouteTracker.instance.pause(); // Simular modal activo

      final buttonFocus = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  ElevatedButton(
                    focusNode: buttonFocus,
                    onPressed: () {},
                    child: const Text('TargetButton'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      MoaiSnackBar.show(
                        ctx,
                        message: 'Aviso importante',
                        hint: 'OK',
                        onAction: () {},
                      );
                    },
                    child: const Text('ShowSnack'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      buttonFocus.requestFocus();
      await tester.pump();
      expect(buttonFocus.hasFocus, isTrue);

      // Disparar snackbar
      await tester.tap(find.text('ShowSnack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El foco debe seguir en el botón original porque hay modal activo (está en pausa)
      expect(buttonFocus.hasFocus, isTrue);
    });

    testWidgets(
        'MoaiSnackBar restaura el foco previo al cerrarse cuando no hay modales',
        (tester) async {
      final buttonFocus = FocusNode();
      late BuildContext navContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                navContext = ctx;
                return Column(
                  children: [
                    ElevatedButton(
                      focusNode: buttonFocus,
                      onPressed: () {},
                      child: const Text('MainButton'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      buttonFocus.requestFocus();
      await tester.pump();
      expect(buttonFocus.hasFocus, isTrue);

      // Disparar snackbar directamente (como lo hace el stream de calendario)
      MoaiSnackBar.show(
        navContext,
        message: 'Aviso normal',
        hint: 'OK',
        onAction: () {},
        duration: const Duration(milliseconds: 500),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El snackbar tomó el foco
      expect(buttonFocus.hasFocus, isFalse);

      // Ocultar el snackbar y esperar a que finalice su salida
      ScaffoldMessenger.of(navContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // El foco fue devuelto automáticamente a buttonFocus
      expect(buttonFocus.hasFocus, isTrue);
    });
  });
}
