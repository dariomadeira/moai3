import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/features/settings/widgets/settings_general_panel.dart';
import 'package:moai3/features/settings/widgets/settings_tv_panel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(
          value: ThemeProvider(prefs),
        ),
        ChangeNotifierProvider<TvSettingsProvider>.value(
          value: TvSettingsProvider(prefs),
        ),
        ChangeNotifierProvider<ChannelProvider>.value(
          value: ChannelProvider(prefs),
        ),
        ChangeNotifierProvider<FavoritesProvider>.value(
          value: FavoritesProvider(prefs),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('renders SettingsTvPanel', (tester) async {
    AppConfig.debugModeOverride = false;
    addTearDown(() => AppConfig.debugModeOverride = null);

    final focusNode = FocusNode();
    await tester.pumpWidget(
      wrap(
        SettingsTvPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('settings_tv_title'), findsOneWidget);
    focusNode.dispose();
  });

  testWidgets('renders SettingsGeneralPanel', (tester) async {
    final focusNode = FocusNode();
    await tester.pumpWidget(
      wrap(
        SettingsGeneralPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('settings_general_title'), findsOneWidget);
    focusNode.dispose();
  });
}
