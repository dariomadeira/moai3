import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/screens/home_screen.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/debug_log_controller.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/playback_stats_controller.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_party_provider_test.dart' show FakeWatchPartyService;

class _OfflinePresence extends SupabasePresenceService {
  @override
  Future<void> updateOnlineStatus({
    required String deviceId,
    required bool online,
  }) async {}

  @override
  Future<void> sendHeartbeat({required String deviceId}) async {}

  @override
  Stream<DeviceRecord> watchDevice(String deviceId) => const Stream.empty();
}

/// Regresión D-pad sobre el HomeScreen real (SPEC-50 fase 8).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool isSelected(WidgetTester tester, String label) => tester
      .getSemantics(find.bySemanticsLabel(label))
      .getSemanticsData()
      .flagsCollection
      .isSelected ==
      Tristate.isTrue;

  /// `true` si el foco está en el nodo [label] o en uno de sus hijos.
  bool focusWithin(String label) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    return focus.debugLabel == label ||
        focus.ancestors.any((n) => n.debugLabel == label);
  }

  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'device_id': 'tv-1',
      'user_code': 'MOAI-0001',
    });
    final prefs = await AppPreferences.init();
    final identity = DeviceIdentityService(prefs);
    final tvSettings = TvSettingsProvider(prefs);
    final channels = ChannelProvider(
      prefs,
      isAdultUnlocked: () => tvSettings.isAdultUnlocked,
    );
    final watchPartyService = FakeWatchPartyService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
          ChangeNotifierProvider(create: (_) => AgendaClockProvider(prefs)),
          ChangeNotifierProvider(create: (_) => WeatherProvider(prefs)),
          ChangeNotifierProvider.value(value: tvSettings),
          ChangeNotifierProvider.value(value: channels),
          ChangeNotifierProvider(create: (_) => FavoritesProvider(prefs)),
          ChangeNotifierProvider(
            create: (_) => CalendarProvider(preferences: prefs, startTicker: false),
          ),
          ChangeNotifierProvider(
            create: (_) => FeaturedMoviesProvider()
              ..setAvailableSections(const {
                FeaturedMoviesProvider.sectionFeatured,
                FeaturedMoviesProvider.sectionMovies,
                FeaturedMoviesProvider.sectionSeries,
              }),
          ),
          ChangeNotifierProvider(create: (_) => PlaybackStatsController()),
          ChangeNotifierProvider(create: (_) => DebugLogController()),
          ChangeNotifierProvider.value(value: channels.pluginHost),
          ChangeNotifierProvider(
            create: (_) => WatchPartyProvider(
              preferences: prefs,
              service: watchPartyService,
              identityService: identity,
            ),
          ),
          Provider<DeviceIdentityService>.value(value: identity),
          Provider<SupabasePresenceService>.value(value: _OfflinePresence()),
          Provider<WatchPartyService>.value(value: watchPartyService),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('back desde el rail fuera de TV vuelve a TV', (tester) async {
    await pumpHome(tester);

    // Rail: TV → Agenda (Destacados, Películas, Series, Agenda) y entrar.
    final rail = find.bySemanticsLabel('home_rail_tv_title');
    expect(rail, findsOneWidget);
    await tester.tap(find.bySemanticsLabel('home_rail_calendar_title'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(isSelected(tester, 'home_rail_calendar_title'), isTrue);

    // Back con el foco en el rail → vuelve a TV.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 500));
    expect(isSelected(tester, 'home_rail_tv_title'), isTrue);
    expect(isSelected(tester, 'home_rail_calendar_title'), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('el rail se recorre con flechas y OK entra a la sección', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.bySemanticsLabel('home_rail_tv_title'));
    await tester.pump(const Duration(milliseconds: 300));

    // TV → Destacados → Películas → Series → Agenda.
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 500));

    expect(isSelected(tester, 'home_rail_calendar_title'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('back desde el contenido devuelve el foco al rail', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.bySemanticsLabel('home_rail_calendar_title'));
    await tester.pump(const Duration(milliseconds: 300));

    // → entra al contenido de la Agenda.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(FocusManager.instance.primaryFocus?.debugLabel, isNot('home_rail'));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 500));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'home_rail');
    expect(isSelected(tester, 'home_rail_calendar_title'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Ajustes es dueño de su foco y recuerda el panel al volver', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.bySemanticsLabel('home_rail_settings_title'));
    await tester.pump(const Duration(milliseconds: 300));

    // → desde el rail entra al panel abierto (TV, el primero).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(focusWithin('settings_tv'), isTrue);

    // Abrir "Acerca de" y salir a TV.
    await tester.tap(find.text('settings_about_title').first);
    // Varios frames: el acordeón anima y el pedido de foco reintenta por frame.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(focusWithin('settings_about'), isTrue);
    await tester.tap(find.bySemanticsLabel('home_rail_tv_title'));
    await tester.pump(const Duration(milliseconds: 500));

    // Volver a Ajustes: → entra de nuevo a "Acerca de".
    await tester.tap(find.bySemanticsLabel('home_rail_settings_title'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 500));
    expect(focusWithin('settings_about'), isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('TV conserva la pestaña al ir a la Agenda y volver', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byIcon(MoaiIcons.tvTabBuscar));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(MoaiIcons.tvTabBuscarSelected), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('home_rail_calendar_title'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(MoaiIcons.tvTabBuscarSelected), findsNothing);

    await tester.tap(find.bySemanticsLabel('home_rail_tv_title'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byIcon(MoaiIcons.tvTabBuscarSelected), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('volver a Ajustes entra al panel recordado sin saltar al siguiente', (
    tester,
  ) async {
    await pumpHome(tester);
    Future<void> frames() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Antes, los paneles con lista tomaban el foco al montarse y el → del
    // rail avanzaba un panel de más.
    const panels = {
      'settings_movies_series_title': 'settings_movies_series',
      'settings_agenda_title': 'settings_agenda',
      'settings_watch_party_title': 'settings_watch_party',
      'settings_general_title': 'settings_general',
    };
    for (final MapEntry(key: title, value: node) in panels.entries) {
      await tester.tap(find.bySemanticsLabel('home_rail_settings_title'));
      await frames();
      await tester.tap(find.text(title).first);
      await frames();
      expect(focusWithin(node), isTrue, reason: 'al abrir $title');
      await tester.tap(find.bySemanticsLabel('home_rail_tv_title'));
      await frames();

      await tester.tap(find.bySemanticsLabel('home_rail_settings_title'));
      await frames();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'home_rail');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await frames();
      expect(focusWithin(node), isTrue, reason: 'al volver a $title');
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
