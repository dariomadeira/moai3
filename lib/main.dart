import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome, DeviceOrientation;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/routers/routers.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/debug_log_controller.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
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
  final channelProvider = ChannelProvider(appPreferences);
  final favoritesProvider = FavoritesProvider(appPreferences);
  final playbackStats = PlaybackStatsController();
  final debugLog = DebugLogController();
  final router = createRouter(tvSettingsProvider);

  runApp(EasyLocalization(
    path: kTranslationsPath,
    supportedLocales: kSupportedLocales,
    fallbackLocale: kFallbackLocale,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: tvSettingsProvider),
        ChangeNotifierProvider.value(value: channelProvider),
        ChangeNotifierProvider.value(value: favoritesProvider),
        ChangeNotifierProvider.value(value: playbackStats),
        ChangeNotifierProvider.value(value: debugLog),
        ChangeNotifierProvider.value(value: channelProvider.pluginHost),
      ],
      child: MyApp(router: router),
    ),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.router});

  final GoRouter router;

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color? _lastSeed;
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;

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
    NotificationHelper.updateContext(context);

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

