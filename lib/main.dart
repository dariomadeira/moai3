import 'dart:async';
import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/routers/routers.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/debug_log_controller.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

class BadCertHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        final hostLower = host.toLowerCase();
        if (kStrictSslHosts.any((strictHost) => hostLower.contains(strictHost))) {
          return false; // Validación estricta SSL
        }
        return true; // Permitir fallback de certificado para otros (ej: scrapers, trackers)
      };
  }
}

void main() async {
  HttpOverrides.global = BadCertHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  MoaiImageCacheManager.clearLegacyCache();
  PaintingBinding.instance.imageCache.maximumSize = kImageCacheMaximumSize;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      kImageCacheMaximumSizeBytes;
  await dotenv.load(fileName: '.env');
  await AppConfig.initialize();
  await PlayerConfig.initialize();

  await EasyLocalization.ensureInitialized();

  if (!AppConfig.tvMode) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  final appPreferences = await AppPreferences.init();
  final themeProvider = ThemeProvider(appPreferences);
  final tvSettingsProvider = TvSettingsProvider(appPreferences);
  final channelProvider = ChannelProvider(
    appPreferences,
    isAdultUnlocked: () => tvSettingsProvider.isAdultUnlocked,
  );
  final favoritesProvider = FavoritesProvider(appPreferences);
  final agendaClock = AgendaClockProvider(appPreferences);
  final calendarProvider = CalendarProvider();
  final playbackStats = PlaybackStatsController();
  final debugLog = DebugLogController();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Error inicializando Supabase: $e');
    }
  }

  final deviceIdentityService = DeviceIdentityService(appPreferences);
  await deviceIdentityService.initialize();
  final supabasePresenceService = SupabasePresenceService();
  final watchPartyService = WatchPartyService();
  final watchPartyProvider = WatchPartyProvider(
    preferences: appPreferences,
    service: watchPartyService,
    identityService: deviceIdentityService,
  );
  final watchPartyVoiceCoordinator = WatchPartyVoiceCoordinator(
    watchPartyProvider: watchPartyProvider,
    watchPartyService: watchPartyService,
    identityService: deviceIdentityService,
  );

  final router = createRouter(
    tvSettingsProvider,
    identityService: deviceIdentityService,
    presenceService: supabasePresenceService,
  );

  runApp(EasyLocalization(
    path: kTranslationsPath,
    supportedLocales: kSupportedLocales,
    fallbackLocale: kFallbackLocale,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: agendaClock),
        ChangeNotifierProvider.value(value: tvSettingsProvider),
        ChangeNotifierProvider.value(value: channelProvider),
        ChangeNotifierProvider.value(value: favoritesProvider),
        ChangeNotifierProvider.value(value: calendarProvider),
        ChangeNotifierProvider.value(value: playbackStats),
        ChangeNotifierProvider.value(value: debugLog),
        ChangeNotifierProvider.value(value: channelProvider.pluginHost),
        ChangeNotifierProvider.value(value: watchPartyProvider),
        ChangeNotifierProvider.value(value: watchPartyVoiceCoordinator),
        Provider<DeviceIdentityService>.value(value: deviceIdentityService),
        Provider<SupabasePresenceService>.value(value: supabasePresenceService),
        Provider<WatchPartyService>.value(value: watchPartyService),
      ],
      child: MyApp(
        router: router,
        identityService: deviceIdentityService,
        presenceService: supabasePresenceService,
      ),
    ),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.router,
    required this.identityService,
    required this.presenceService,
  });

  final GoRouter router;
  final DeviceIdentityService identityService;
  final SupabasePresenceService presenceService;

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppLifecycleListener? _lifecycleListener;
  Timer? _heartbeatTimer;
  bool _isInForeground = true;
  Color? _lastSeed;
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;

  static const Duration _heartbeatInterval = Duration(seconds: 45);

  @override
  void initState() {
    super.initState();
    final deviceId = widget.identityService.getOrCreateDeviceId();
    _startHeartbeat(deviceId);

    _lifecycleListener = AppLifecycleListener(
      onResume: () => _handleForeground(deviceId),
      onPause: () => _handleBackground(deviceId),
      onDetach: () => _handleBackground(deviceId),
      onHide: () => _handleBackground(deviceId),
    );
  }

  void _handleForeground(String deviceId) {
    if (_isInForeground) return;
    _isInForeground = true;
    widget.presenceService.updateOnlineStatus(
      deviceId: deviceId,
      online: true,
    );
    _startHeartbeat(deviceId);
  }

  void _handleBackground(String deviceId) {
    if (!_isInForeground) return;
    _isInForeground = false;
    _stopHeartbeat();
    widget.presenceService.updateOnlineStatus(
      deviceId: deviceId,
      online: false,
    );
  }

  void _startHeartbeat(String deviceId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      widget.presenceService.sendHeartbeat(deviceId: deviceId);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    _stopHeartbeat();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  ThemeData _themeFor(ColorScheme scheme) {
    return ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainer,
      useMaterial3: true,
      fontFamily: MoaiText.bodyFamily,
      textTheme: MoaiText.textTheme(scheme),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }

  void _updateThemesIfNeeded(Color seed) {
    if (_lastSeed == seed && _cachedLightTheme != null && _cachedDarkTheme != null) {
      return;
    }
    _lastSeed = seed;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).harmonized();
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).harmonized();
    _cachedLightTheme = _themeFor(lightScheme);
    _cachedDarkTheme = _themeFor(darkScheme);
  }

  @override
  Widget build(BuildContext context) {
    NotificationHelper.initialize(MyApp.scaffoldMessengerKey);

    final (themeMode, seed) = context.select<ThemeProvider, (ThemeMode, Color)>(
      (theme) => (theme.themeMode, theme.accentSeed),
    );

    _updateThemesIfNeeded(seed);

    return MaterialApp.router(
      scaffoldMessengerKey: MyApp.scaffoldMessengerKey,
      routerConfig: widget.router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: kAppName,
      themeMode: themeMode,
      theme: _cachedLightTheme!,
      darkTheme: _cachedDarkTheme!,
      debugShowCheckedModeBanner: false,
    );
  }
}

