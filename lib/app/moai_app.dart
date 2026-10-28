import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/feedback/notification_helper.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

class MoaiApp extends StatefulWidget {
  const MoaiApp({
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
  State<MoaiApp> createState() => _MoaiAppState();
}

class _MoaiAppState extends State<MoaiApp> {
  AppLifecycleListener? _lifecycleListener;
  bool _isInForeground = true;
  Color? _lastSeed;
  ThemeData? _cachedLightTheme;
  ThemeData? _cachedDarkTheme;

  @override
  void initState() {
    super.initState();
    NotificationHelper.initialize(MoaiApp.scaffoldMessengerKey);
    final deviceId = widget.identityService.getOrCreateDeviceId();

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
    widget.presenceService.updateOnlineStatus(deviceId: deviceId, online: true);
  }

  void _handleBackground(String deviceId) {
    if (!_isInForeground) return;
    _isInForeground = false;
    widget.presenceService.updateOnlineStatus(
      deviceId: deviceId,
      online: false,
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  ThemeData _themeFor(ColorScheme scheme) {
    return ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainer,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.iOS: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.windows: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.linux: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.macOS: MoaiFadePageTransitionsBuilder(),
        },
      ),
      fontFamily: MoaiText.bodyFamily,
      textTheme: MoaiText.textTheme(scheme),
      iconTheme: const IconThemeData(
        weight: 1.2,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
    );
  }

  void _updateThemesIfNeeded(Color seed) {
    if (_lastSeed == seed &&
        _cachedLightTheme != null &&
        _cachedDarkTheme != null) {
      return;
    }
    _lastSeed = seed;
    final lightScheme = ColorScheme.fromSeed(seedColor: seed).harmonized();
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).harmonized();
    _cachedLightTheme = _themeFor(lightScheme);
    _cachedDarkTheme = _themeFor(darkScheme);
  }

  @override
  Widget build(BuildContext context) {
    final (themeMode, seed) = context.select<ThemeProvider, (ThemeMode, Color)>(
      (theme) => (theme.themeMode, theme.accentSeed),
    );

    _updateThemesIfNeeded(seed);

    return MaterialApp.router(
      scaffoldMessengerKey: MoaiApp.scaffoldMessengerKey,
      routerConfig: widget.router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: kAppName,
      themeMode: themeMode,
      theme: _cachedLightTheme!,
      darkTheme: _cachedDarkTheme!,
      debugShowCheckedModeBanner: false,
      // Toda la app va sobre el fondo ambiente: los componentes compartidos
      // (paneles, fichas, switches) se dibujan de cristal en todas las rutas
      // y diálogos.
      builder: (context, child) =>
          MoaiGlassScope(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Transición de pantalla por fundido directo:
/// - Sin desplazamiento lateral (sin movimiento 'de costado').
/// - La pantalla saliente permanece debajo hasta ser cubierta por completo,
///   eliminando destellos del fondo de la ventana.
class MoaiFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const MoaiFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}
