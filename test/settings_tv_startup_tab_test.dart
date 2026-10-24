import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/features/settings/widgets/settings_tv_panel.dart';
import 'package:moai3/features/settings/widgets/settings_tv_startup_tab_row.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  group('TvSettingsProvider - startupTvTab', () {
    test('default value is explore', () {
      final provider = TvSettingsProvider(prefs);
      expect(provider.startupTvTab, TvTab.explore);
    });

    test('updates and persists startupTvTab', () async {
      final provider = TvSettingsProvider(prefs);
      await provider.setStartupTvTab(TvTab.search);
      expect(provider.startupTvTab, TvTab.search);

      // Nueva instancia leyendo del mismo storage
      final reloaded = TvSettingsProvider(prefs);
      expect(reloaded.startupTvTab, TvTab.search);

      await reloaded.setStartupTvTab(TvTab.groups);
      expect(reloaded.startupTvTab, TvTab.groups);
    });

    test('un valor guardado desconocido vuelve a explore', () async {
      SharedPreferences.setMockInitialValues({'startup_tv_tab': 'invalid_tab'});
      final provider = TvSettingsProvider(await AppPreferences.init());
      expect(provider.startupTvTab, TvTab.explore);
    });
  });

  group('SettingsTvStartupTabRow Widget', () {
    testWidgets(
        'sin editar ← → cambian de panel; OK entra a editar y ← → cambian la opción',
        (tester) async {
      var currentTab = TvTab.explore;
      var panelLeft = 0;
      var panelRight = 0;
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SettingsTvStartupTabRow(
                  focusNode: focusNode,
                  selectedTab: currentTab,
                  onChanged: (tab) => setState(() => currentTab = tab),
                  onKeyLeft: () => panelLeft++,
                  onKeyRight: () => panelRight++,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SettingsTvStartupTabRow), findsOneWidget);
      expect(find.byIcon(MoaiIcons.settingsTvStartupTab), findsOneWidget);

      focusNode.requestFocus();
      await tester.pump();

      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyEvent(key);
        await tester.pump();
      }

      // Sin editar: ← → navegan entre paneles y no tocan la opción.
      await press(LogicalKeyboardKey.arrowRight);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(panelRight, 1);
      expect(panelLeft, 1);
      expect(currentTab, TvTab.explore);

      // OK entra a editar: ← → cambian la opción.
      await press(LogicalKeyboardKey.select);
      await press(LogicalKeyboardKey.arrowRight);
      expect(currentTab, TvTab.search);
      await press(LogicalKeyboardKey.arrowRight);
      expect(currentTab, TvTab.groups);
      await press(LogicalKeyboardKey.arrowRight);
      expect(currentTab, TvTab.groups);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(currentTab, TvTab.search);
      expect(panelRight, 1);

      // OK sale de editar: → vuelve a cambiar de panel.
      await press(LogicalKeyboardKey.select);
      await press(LogicalKeyboardKey.arrowRight);
      expect(panelRight, 2);
      expect(currentTab, TvTab.search);

      // Atrás (Escape en el test) también sale de editar.
      await press(LogicalKeyboardKey.select);
      await press(LogicalKeyboardKey.escape);
      await press(LogicalKeyboardKey.arrowLeft);
      expect(panelLeft, 2);
      expect(currentTab, TvTab.search);

      focusNode.dispose();
    });
  });

  group('SettingsTvPanel integration', () {
    testWidgets('renders SettingsTvStartupTabRow inside SettingsTvPanel',
        (tester) async {
      final provider = TvSettingsProvider(prefs);
      final focusNode = FocusNode();

      await tester.pumpWidget(
        ChangeNotifierProvider<TvSettingsProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 600,
                child: SettingsTvPanel(
                  focusNode: focusNode,
                  onKeyLeft: () {},
                  onKeyRight: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SettingsTvStartupTabRow), findsOneWidget);
      focusNode.dispose();
    });
  });
}
