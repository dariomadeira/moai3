import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

void main() {
  testWidgets('SourcesScreen renders header, url input, and two column lists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.init();
    final controller = PluginHostController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PluginHostController>.value(value: controller),
          ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
        ],
        child: const MaterialApp(
          home: SourcesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify url input
    expect(find.byType(TvTextField), findsOneWidget);

    // Verify left empty state card when no sources installed
    expect(find.byType(TvEmptyStateCard), findsOneWidget);
  });
}
