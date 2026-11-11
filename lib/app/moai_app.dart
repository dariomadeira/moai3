import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/config/constants.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/theme/moai_theme.dart';
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

  @override
  void initState() {
    super.initState();
    NotificationHelper.initialize(MoaiApp.scaffoldMessengerKey);
    final deviceId = widget.identityService.getOrCreateDeviceId();

    // Sólo apaga (también antes de llegar al Inicio); volver a primer plano
    // lo decide [PresenceCoordinator], que conoce la sección.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _isInForeground = true,
      onPause: () => _handleBackground(deviceId),
      onDetach: () => _handleBackground(deviceId),
      onHide: () => _handleBackground(deviceId),
    );
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

  Color? _themeSeed;
  ThemeData? _lightTheme;
  ThemeData? _darkTheme;

  /// Los dos temas ([MoaiTheme.light] y [MoaiTheme.dark]); se arman sólo
  /// al cambiar el color.
  void _buildThemesFor(Color seed) {
    if (_themeSeed == seed && _lightTheme != null) return;
    _themeSeed = seed;
    _lightTheme = MoaiTheme.light(seed);
    _darkTheme = MoaiTheme.dark(seed);
  }

  @override
  Widget build(BuildContext context) {
    final (themeMode, seed) = context.select<ThemeProvider, (ThemeMode, Color)>(
      (theme) => (theme.themeMode, theme.accentSeed),
    );

    _buildThemesFor(seed);
    // Los títulos con degradado terminan en el acento (de noche, aclarado).
    HomeClock.setAccent(seed, dark: themeMode == ThemeMode.dark);

    return MaterialApp.router(
      scaffoldMessengerKey: MoaiApp.scaffoldMessengerKey,
      routerConfig: widget.router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: kAppName,
      // REDISEÑO: la paleta de Cleanly, de día y de noche (2026-11-10); el
      // modo lo elige cada uno en Ajustes (arranca en claro) y el acento
      // sigue al color de resalte.
      themeMode: themeMode,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      debugShowCheckedModeBanner: false,
      // Toda la app va sobre el fondo ambiente: los componentes compartidos
      // (paneles, fichas, switches) se dibujan de cristal en todas las rutas
      // y diálogos.
      builder: (context, child) =>
          MoaiGlassScope(child: child ?? const SizedBox.shrink()),
    );
  }
}
