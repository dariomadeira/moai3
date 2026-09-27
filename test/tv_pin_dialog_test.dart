import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/dialogs/tv_pin_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              showGeneralDialog(
                context: context,
                pageBuilder: (context, _, _) => child,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TvPinDialog Tests', () {
    testWidgets('renders numeric keypad 1-9, 0, backspace and cancel', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TvPinDialog(
            mode: TvPinDialogMode.verify,
            customTitle: 'Test PIN',
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test PIN'), findsOneWidget);

      // Check all digits exist
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Check icons
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close_outlined), findsOneWidget);
    });

    testWidgets('create mode transitions from step 1 to step 2 without closing dialog', (tester) async {
      final prefs = await AppPreferences.init();
      final tvSettings = TvSettingsProvider(prefs);

      await tester.pumpWidget(
        _wrap(
          TvPinDialog(
            mode: TvPinDialogMode.create,
            tvSettings: tvSettings,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Step 1:
      expect(find.text('parental_pin_title_create'), findsOneWidget);

      // Verify Step Badge: tertiaryContainer, no border, onTertiaryContainer
      final stepFinder = find.text('parental_pin_step');
      expect(stepFinder, findsOneWidget);
      final stepContainer = tester.widget<Container>(
        find.ancestor(of: stepFinder, matching: find.byType(Container)).first,
      );
      final boxDecoration = stepContainer.decoration as BoxDecoration;
      expect(boxDecoration.border, isNull);
      final theme = Theme.of(tester.element(stepFinder));
      expect(boxDecoration.color, equals(theme.colorScheme.tertiaryContainer));
      final stepText = tester.widget<Text>(stepFinder);
      expect(stepText.style?.color, equals(theme.colorScheme.onTertiaryContainer));

      // Tap 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // Now it should have transitioned smoothly to Step 2 ("parental_pin_title_confirm")
      expect(find.text('parental_pin_title_confirm'), findsOneWidget);
      expect(find.byType(TvPinDialog), findsOneWidget);

      // Tap 1, 2, 3, 4 to confirm
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // PIN should now be set in tvSettings
      expect(tvSettings.hasParentalPin, isTrue);
      expect(tvSettings.verifyPin('1234'), isTrue);
    });

    testWidgets('create mode with mismatch shows error and resets without closing dialog', (tester) async {
      final prefs = await AppPreferences.init();
      final tvSettings = TvSettingsProvider(prefs);

      await tester.pumpWidget(
        _wrap(
          TvPinDialog(
            mode: TvPinDialogMode.create,
            tvSettings: tvSettings,
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      expect(find.text('parental_pin_title_confirm'), findsOneWidget);

      // Enter 1, 2, 3, 5 (mismatch)
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      // Dialog is still open!
      expect(find.byType(TvPinDialog), findsOneWidget);
      expect(find.text('parental_pin_error_mismatch'), findsOneWidget);
      expect(tvSettings.hasParentalPin, isFalse);
    });

    testWidgets('handles physical keyboard numeric input', (tester) async {
      String? enteredPin;

      await tester.pumpWidget(
        _wrap(
          TvPinDialog(
            mode: TvPinDialogMode.verify,
            onValidate: (pin) async {
              enteredPin = pin;
              return true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();

      expect(enteredPin, equals('7890'));
    });
  });
}
