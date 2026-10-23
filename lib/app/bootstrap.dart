import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/config/app_info.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/routers/routers.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/debug_log_controller.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/playback_stats_controller.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/state/weather_provider.dart';

class BadCertHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Estricto en hosts críticos; permisivo en streams, logos y scrapers.
        return !isStrictSslHost(host);
      };
  }
}

/// Todo lo que la app necesita, armado una sola vez por [AppBootstrap.run].
class AppDependencies {
  AppDependencies({
    required this.preferences,
    required this.theme,
    required this.tvSettings,
    required this.pluginHost,
    required this.channels,
    required this.favorites,
    required this.agendaClock,
    required this.weather,
    required this.calendar,
    required this.featuredMovies,
    required this.playbackStats,
    required this.debugLog,
    required this.identity,
    required this.presence,
    required this.watchPartyService,
    required this.watchParty,
    required this.voiceCoordinator,
    required this.router,
  });

  final AppPreferences preferences;
  final ThemeProvider theme;
  final TvSettingsProvider tvSettings;
  final PluginHostController pluginHost;
  final ChannelProvider channels;
  final FavoritesProvider favorites;
  final AgendaClockProvider agendaClock;
  final WeatherProvider weather;
  final CalendarProvider calendar;
  final FeaturedMoviesProvider featuredMovies;
  final PlaybackStatsController playbackStats;
  final DebugLogController debugLog;
  final DeviceIdentityService identity;
  final SupabasePresenceService presence;
  final WatchPartyService watchPartyService;
  final WatchPartyProvider watchParty;
  final WatchPartyVoiceCoordinator voiceCoordinator;
  final GoRouter router;

  /// Providers de la raíz del árbol.
  List<SingleChildWidget> get providers => [
    ChangeNotifierProvider.value(value: theme),
    ChangeNotifierProvider.value(value: agendaClock),
    ChangeNotifierProvider.value(value: weather),
    ChangeNotifierProvider.value(value: tvSettings),
    ChangeNotifierProvider.value(value: channels),
    ChangeNotifierProvider.value(value: favorites),
    ChangeNotifierProvider.value(value: calendar),
    ChangeNotifierProvider.value(value: featuredMovies),
    ChangeNotifierProvider.value(value: playbackStats),
    ChangeNotifierProvider.value(value: debugLog),
    ChangeNotifierProvider.value(value: pluginHost),
    ChangeNotifierProvider.value(value: watchParty),
    ChangeNotifierProvider.value(value: voiceCoordinator),
    ChangeNotifierProvider<ArcadeNetplayService>.value(
      value: ArcadeNetplayService.instance,
    ),
    Provider<DeviceIdentityService>.value(value: identity),
    Provider<SupabasePresenceService>.value(value: presence),
    Provider<WatchPartyService>.value(value: watchPartyService),
  ];
}

/// Arranque de la app: configuración, servicios y providers.
abstract final class AppBootstrap {
  static Future<AppDependencies> run() async {
    HttpOverrides.global = BadCertHttpOverrides();
    WidgetsFlutterBinding.ensureInitialized();
    PaintingBinding.instance.imageCache.maximumSize = kImageCacheMaximumSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        kImageCacheMaximumSizeBytes;
    try {
      await dotenv.load();
    } catch (e, st) {
      debugPrint('dotenv: no se pudo cargar .env ($e)\n$st');
    }
    await AppConfig.initialize();

    // Independientes entre sí: en paralelo para acortar el arranque (SPEC-50 §6.2).
    final prefsFuture = AppPreferences.init();
    await Future.wait([
      AppInfo.initialize(),
      EasyLocalization.ensureInitialized(),
      prefsFuture,
      SystemChrome.setPreferredOrientations(
        AppConfig.tvMode
            ? DeviceOrientation.values
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
      ),
    ]);

    final preferences = await prefsFuture;
    await ArcadePluginService.instance.init(preferences);
    unawaited(MoaiImageCacheManager.clearLegacyCacheOnce(preferences));

    final theme = ThemeProvider(preferences);
    final tvSettings = TvSettingsProvider(preferences);
    final pluginHost = PluginHostController();
    final channels = ChannelProvider(
      preferences,
      pluginHost: pluginHost,
      isAdultUnlocked: () => tvSettings.isAdultUnlocked,
    );
    final favorites = FavoritesProvider(preferences);
    final agendaClock = AgendaClockProvider(preferences);
    final weather = WeatherProvider(preferences);
    final calendar = CalendarProvider(preferences: preferences);
    final featuredMovies = FeaturedMoviesProvider();
    final playbackStats = PlaybackStatsController();
    final debugLog = DebugLogController();

    final supabaseReady = await _initSupabase();

    final identity = DeviceIdentityService(preferences);
    await identity.initialize();
    final presence = SupabasePresenceService();
    final watchPartyService = WatchPartyService();
    final watchParty = WatchPartyProvider(
      preferences: preferences,
      service: watchPartyService,
      identityService: identity,
    );

    if (supabaseReady) {
      ArcadeNetplayService.instance.initialize(
        client: Supabase.instance.client,
        myDeviceId: identity.getOrCreateDeviceId(),
      );
    }

    return AppDependencies(
      preferences: preferences,
      theme: theme,
      tvSettings: tvSettings,
      pluginHost: pluginHost,
      channels: channels,
      favorites: favorites,
      agendaClock: agendaClock,
      weather: weather,
      calendar: calendar,
      featuredMovies: featuredMovies,
      playbackStats: playbackStats,
      debugLog: debugLog,
      identity: identity,
      presence: presence,
      watchPartyService: watchPartyService,
      watchParty: watchParty,
      voiceCoordinator: WatchPartyVoiceCoordinator(
        watchPartyProvider: watchParty,
        watchPartyService: watchPartyService,
        identityService: identity,
      ),
      router: createRouter(
        identityService: identity,
        presenceService: presence,
      ),
    );
  }

  /// `true` si Supabase quedó listo (hay credenciales y no falló).
  static Future<bool> _initSupabase() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    if (url.isEmpty || anonKey.isEmpty) return false;
    try {
      await Supabase.initialize(
        url: url,
        // ignore: deprecated_member_use
        anonKey: anonKey,
      );
      return true;
    } catch (e) {
      debugPrint('Error inicializando Supabase: $e');
      return false;
    }
  }
}
