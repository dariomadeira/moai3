import 'dart:async';
import 'package:moai3/config/constants.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/config/app_info.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/vpn_nodes.dart';
import 'package:moai3/services/vpn_service.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

part 'loading/loading_boot.dart';
part 'loading/loading_views.dart';

/// Etapa del arranque que muestra el recuadro de estado.
enum _BootStep {
  device(MoaiIcons.bootDevice),
  secure(MoaiIcons.bootSecure),
  session(MoaiIcons.bootSession),
  catalog(MoaiIcons.bootCatalog),
  ready(MoaiIcons.bootReady);

  const _BootStep(this.icon);

  final IconData icon;
}

/// Ícono de cada mensaje; los que no están usan el de su etapa.
const Map<String, IconData> _statusIcons = {
  LocaleKeys.loading_permission_required: MoaiIcons.bootPermission,
  LocaleKeys.loading_init_services: MoaiIcons.bootServices,
  LocaleKeys.loading_connecting_server: MoaiIcons.bootServer,
  LocaleKeys.loading_secure_retry: MoaiIcons.bootRetry,
  LocaleKeys.loading_secure_verified: MoaiIcons.bootSecureReady,
  LocaleKeys.loading_session_failed: MoaiIcons.bootSessionFailed,
  LocaleKeys.loading_catalog_updated: MoaiIcons.bootCatalogUpdated,
  LocaleKeys.loading_catalog_cached: MoaiIcons.bootCatalogCached,
  LocaleKeys.loading_catalog_not_updated: MoaiIcons.bootCatalogStale,
  LocaleKeys.loading_secure_disconnecting: MoaiIcons.bootDisconnect,
};

/// Pantalla de arranque: verificación del dispositivo, VPN + login y, si
/// toca, descarga del catálogo (SPEC-22 §4.1, SPEC-39 §4). Fondo: el de la
/// app desenfocado; el estado va en un recuadro de vidrio.
class LoadingScreen extends StatefulWidget {
  final DeviceIdentityService identityService;
  final SupabasePresenceService presenceService;

  const LoadingScreen({
    super.key,
    required this.identityService,
    required this.presenceService,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  /// Opacidad máxima del aura del logo (late entre 0,12 y esto).
  static const double _glowMax = 0.28;

  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'loading_retry');
  final FocusNode _cancelCatalogFocus = FocusNode(
    debugLabel: 'loading_cancel_catalog',
  );

  bool _isLoading = true;
  String? _errorMessage;
  _BootStep _step = _BootStep.device;
  String _statusText = LocaleKeys.loading_connecting.tr();

  /// Ícono del mensaje que se está mostrando.
  IconData _icon = _BootStep.device.icon;

  /// Segunda línea del recuadro (intento, secciones bajadas); null = nada.
  String? _detailText;
  bool _catalogUpdateInProgress = false;
  bool _catalogCancelRequested = false;
  DateTime? _storedCatalogAt;

  /// Intentos de VPN + login + descarga, cada uno con otro endpoint.
  static const int _maxAttempts = 4;

  static const List<String> _catalogSections = [
    FeaturedMoviesProvider.sectionMovies,
    FeaturedMoviesProvider.sectionFeatured,
    FeaturedMoviesProvider.sectionSeries,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.12 / _glowMax, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutCubic),
    );

    _startVerification();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _retryFocusNode.dispose();
    _cancelCatalogFocus.dispose();
    super.dispose();
  }

  Future<void> _pause(Duration duration) async {
    const step = Duration(milliseconds: 150);
    var left = duration;
    while (left > Duration.zero && mounted && !_catalogCancelRequested) {
      final slice = left < step ? left : step;
      await Future.delayed(slice);
      left -= slice;
    }
  }

  void _setStatus(String key) {
    if (!mounted) return;
    setState(() {
      _statusText = key.tr();
      _icon = _statusIcons[key] ?? _step.icon;
    });
  }

  void _setStep(_BootStep step, String key, {String? detail}) {
    if (!mounted) return;
    setState(() {
      _step = step;
      _statusText = key.tr();
      _icon = _statusIcons[key] ?? step.icon;
      _detailText = detail;
    });
  }

  void _setDetail(String? detail) {
    if (mounted) setState(() => _detailText = detail);
  }

  String _attemptDetail(int attempt, int total) => LocaleKeys.loading_attempt
      .tr(namedArgs: {'current': '$attempt', 'total': '$total'});

  /// Corta solo la descarga del catálogo; el login ya terminó.
  void _cancelCatalogUpdate() {
    if (_catalogCancelRequested) return;
    setState(() => _catalogCancelRequested = true);
    MoiamovApiService.instance.cancelActiveRequests();
  }

  String _cancelCatalogLabel() {
    final savedAt = _storedCatalogAt;
    if (savedAt == null) return LocaleKeys.loading_catalog_cancel_no_date.tr();
    final date = MoaiFormats.date(savedAt.toLocal());
    return LocaleKeys.loading_catalog_cancel.tr(namedArgs: {'date': date});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // El fondo de la app desenfocado (background_color_blur.webp, el del
      // vidrio esmerilado); sólo el logo late con la animación (SPEC-50 §6.1).
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  MoaiAmbientBackground.blurredAssetFor(scheme.brightness),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // El latido sólo escala y cambia la opacidad de capas ya
                    // pintadas: la sombra difuminada se pinta una vez.
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FadeTransition(
                            opacity: _glowAnimation,
                            child: RepaintBoundary(
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    // Blanca: con el acento se veía celeste.
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: _glowMax,
                                      ),
                                      blurRadius: 48,
                                      spreadRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          RepaintBoundary(child: _buildLogo(context)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isLoading
                          ? _buildStatusCard(context, scheme)
                          : _buildErrorCard(context, scheme),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              // La versión en una pastilla con el cristal de los botones.
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: moaiGlassButtonDecoration(scheme, focused: false),
                  child: Text(
                    'v${AppInfo.version}',
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Para las extensiones de los `part` (setState es protegido).
  void _update(VoidCallback fn) => setState(fn);
}
