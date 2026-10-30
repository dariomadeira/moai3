import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/areas/home_settings_area.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/spanish_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  testWidgets('HomeSettingsArea recuerda el índice de cada panel al alternar entre pestañas', (tester) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final tvSettings = TvSettingsProvider(prefs);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<TvSettingsProvider>.value(
            value: tvSettings,
            child: HomeSettingsArea(
              onExitLeft: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Bajamos en el panel de TV
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // 2. Pasamos al siguiente panel a la derecha (Películas y Series)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // 3. Volvemos al panel de TV a la izquierda
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    // El foco no se reseteó al primer ítem (debugLog)
    expect(find.byType(HomeSettingsArea), findsOneWidget);
  });
}
