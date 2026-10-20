import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(provider.startupTvTab, 'explore');
    });

    test('updates and persists startupTvTab', () async {
      final provider = TvSettingsProvider(prefs);
      await provider.setStartupTvTab('search');
      expect(provider.startupTvTab, 'search');

      // Nueva instancia leyendo del mismo storage
      final reloaded = TvSettingsProvider(prefs);
      expect(reloaded.startupTvTab, 'search');

      await reloaded.setStartupTvTab('groups');
      expect(reloaded.startupTvTab, 'groups');
    });

    test('ignores invalid tab strings', () async {
      final provider = TvSettingsProvider(prefs);
      await provider.setStartupTvTab('invalid_tab');
      expect(provider.startupTvTab, 'explore');
    });
  });

  group('SettingsTvStartupTabRow Widget', () {
    testWidgets('renders row and changes option with D-pad left/right',
        (tester) async {
      String currentTab = 'explore';
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
                  onKeyLeft: () {},
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

      // D-Pad Right: explore -> search
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(currentTab, 'search');

      // D-Pad Right: search -> groups
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(currentTab, 'groups');

      // D-Pad Left: groups -> search
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(currentTab, 'search');

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
