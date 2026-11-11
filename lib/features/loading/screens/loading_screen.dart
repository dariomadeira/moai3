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

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _step = _BootStep.device;
      _statusText = LocaleKeys.loading_connecting.tr();
      _icon = _BootStep.device.icon;
      _detailText = null;
    });

    MoiamovApiService.logLine('▶ Inicio de verificación de arranque Moai');

    final startTime = DateTime.now();

    try {
      final identity = await widget.identityService.getIdentity();
      final localNickname = widget.identityService.getNickname();
      final result = await widget.presenceService.verifyAndRegisterDevice(
        deviceId: identity.deviceId,
        appVersion: identity.appVersion,
        nickname: localNickname,
      );

      if (!mounted) return;

      final record = result.record;
      if (record.userCode != null) {
        await widget.identityService.saveUserCode(record.userCode!);
      }
      if (record.nickname != null && record.nickname!.trim().isNotEmpty) {
        await widget.identityService.saveNickname(record.nickname!.trim());
      } else if (localNickname != null && localNickname.trim().isNotEmpty) {
        await widget.identityService.saveNickname(localNickname.trim());
      }

      if (!mounted) return;

      final userCode = record.userCode;
      if (userCode != null) {
        context.read<WatchPartyProvider?>()?.updateUserCode(userCode);
      }

      // Si el dispositivo está bloqueado (RB-04 / CASO-UC-02)
      if (!record.isActive) {
        context.go('/blocked', extra: record.blockReason);
        return;
      }

      if (kStartupLoginEnabled) {
        await _syncSessionAndCatalog(context.read<TvSettingsProvider>());
        if (!mounted) return;

        // Un mínimo para que el arranque no sea un parpadeo.
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < const Duration(milliseconds: 1200)) {
          await Future.delayed(const Duration(milliseconds: 1200) - elapsed);
        }

        if (!mounted) return;

        _setStep(_BootStep.ready, LocaleKeys.loading_ready);
        await Future.delayed(const Duration(milliseconds: 700));
      } else {
        // Desarrollo: sin login, con el catálogo guardado.
        MoiamovApiService.logLine(
          '⏭ Login de arranque desactivado (desarrollo)',
        );
        final available = await MoiamovApiService.instance.savedSections();
        if (!mounted) return;
        context.read<FeaturedMoviesProvider>().setAvailableSections(available);
      }

      if (!mounted) return;

      // Dispositivo activo -> Ir a Overlap, NicknameSetup o Home
      final effectiveNick =
          (record.nickname != null && record.nickname!.trim().isNotEmpty)
          ? record.nickname!.trim()
          : (localNickname != null && localNickname.trim().isNotEmpty
                ? localNickname.trim()
                : widget.identityService.getNickname()?.trim());

      if (!context.read<TvSettingsProvider>().hasOverlapConfig) {
        context.go('/overlap');
      } else if (effectiveNick == null || effectiveNick.isEmpty) {
        context.go('/nickname_setup');
      } else {
        context.go('/home');
      }
    } catch (e, st) {
      MoiamovApiService.logLine(
        e is TimeoutException
            ? '❌ Verificación del dispositivo: $e'
            : '❌ Verificación del dispositivo: $e\n$st',
      );
      try {
        await VpnService.instance.disconnect();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = LocaleKeys.loading_error_connection.tr();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retryFocusNode.requestFocus();
      });
    }
  }

  /// VPN + login en todo arranque y, si toca, descarga del catálogo
  /// (SPEC-39 §4). No lanza: si algo falla, Destacados,
  /// Películas y Series quedan ocultas y se sigue al home.
  Future<void> _syncSessionAndCatalog(TvSettingsProvider tvSettings) async {
    final api = MoiamovApiService.instance;
    final vpn = VpnService.instance;
    var sessionOk = false;

    try {
      final hasCatalog = (await api.savedSections()).isNotEmpty;
      _storedCatalogAt = await api.lastSavedCatalogAt();
      final needsUpdate =
          !hasCatalog ||
          TvSettingsProvider.shouldAttemptCatalogUpdate(
            savedAt: _storedCatalogAt,
            frequency: tvSettings.catalogUpdateFrequency,
          );
      MoiamovApiService.logLine(
        'Arranque: catálogo=${hasCatalog ? 'sí' : 'no'} '
        'fecha=${_storedCatalogAt?.toIso8601String() ?? 'null'} '
        'freq=${tvSettings.catalogUpdateFrequency.storageValue} '
        '→ actualizar=$needsUpdate',
      );

      api.beginCatalogSync();
      vpn.resetConnectCancellation();
      _catalogCancelRequested = false;
      final downloaded = <String>{};

      // Endpoints (nodo + puerto) en el orden del ranking (SPEC-39 §4.1).
      // Tras cada falla se reacomoda la cola: los del mismo servidor pasan
      // al final. Los resultados se anotan al final.
      final ranking = VpnNodeRanking();
      var queue = await ranking.orderedEndpoints();
      final total = queue.length < _maxAttempts ? queue.length : _maxAttempts;
      final results = <VpnAttemptResult>[];
      var anyTunnel = false;

      Future<void> rotate(VpnEndpoint failed, {bool dropNode = false}) async {
        queue = VpnNodeRanking.afterFailure(queue, failed, dropNode: dropNode);
        _setStep(_BootStep.secure, LocaleKeys.loading_secure_retry);
        await vpn.disconnect();
        await _pause(const Duration(milliseconds: 500));
      }

      // El permiso VPN se pide dentro de connect (el plugin guarda la
      // config, muestra el aviso del SO y al OK arranca el túnel). No usar
      // requestPermissionAndroid aparte: devuelve false al mostrar el diálogo.
      for (
        var attempt = 1;
        attempt <= total && queue.isNotEmpty && mounted;
        attempt++
      ) {
        final endpoint = queue.removeAt(0);
        final attemptStart = DateTime.now();
        final detail = attempt > 1 ? _attemptDetail(attempt, total) : null;
        _setStep(
          _BootStep.secure,
          LocaleKeys.loading_secure_connecting,
          detail: detail,
        );
        MoiamovApiService.logLine('Intento $attempt/$total: $endpoint');

        final connection = await vpn.connect(
          endpoint,
          onStatusUpdate: _setStatus,
        );
        if (connection == VpnConnectResult.permissionDenied) {
          MoiamovApiService.logLine('Permiso VPN rechazado por el usuario.');
          break;
        }
        if (connection == VpnConnectResult.cancelled) break;
        if (connection != VpnConnectResult.connected) {
          results.add((
            endpoint: endpoint,
            attempt: VpnAttempt.failure,
            elapsed: null,
          ));
          MoiamovApiService.logLine('$endpoint: el túnel no conectó.');
          await rotate(endpoint);
          continue;
        }
        anyTunnel = true;

        // Por dónde sale, sólo para el log: no frena el arranque (si la
        // región no sirve, lo dice el portal al pedir la sesión).
        final country = endpoint.node.country;
        unawaited(
          vpn
              .checkExit(country: country)
              .then(
                (exit) => MoiamovApiService.logLine(
                  'Salida $endpoint: ${vpn.lastExitIp} '
                  '(${vpn.lastExitCountry}, esperado $country: ${exit.name})',
                ),
              ),
        );

        // Un respiro para que la interfaz tun0 tenga rutas y DNS.
        _setStep(
          _BootStep.secure,
          LocaleKeys.loading_secure_verified,
          detail: detail,
        );
        await _pause(const Duration(milliseconds: 1000));
        _setStep(
          _BootStep.session,
          LocaleKeys.loading_session_init,
          detail: detail,
        );
        MoiamovApiService.logLine(
          'Solicitando sesión de dispositivo (sin credenciales)...',
        );
        var session = await api.ensureSession();
        // Un corte de red apenas sube el túnel suele pasar solo: se
        // reintenta una vez con el mismo endpoint antes de cambiarlo.
        if (!session && api.lastSessionNetworkFailure && mounted) {
          MoiamovApiService.logLine(
            '$endpoint: la red no contestó; reintento con el mismo...',
          );
          await _pause(const Duration(milliseconds: 1500));
          if (!_catalogCancelRequested) session = await api.ensureSession();
        }
        if (!session) {
          final region = api.lastSessionRegionRejected;
          results.add((
            endpoint: endpoint,
            // Sin respuesta de la red no es culpa del endpoint.
            attempt: api.lastSessionNetworkFailure
                ? VpnAttempt.transient
                : VpnAttempt.failure,
            elapsed: null,
          ));
          MoiamovApiService.logLine(
            region
                ? '$endpoint: el portal rechazó la salida; otro servidor...'
                : api.lastSessionNetworkFailure
                ? '$endpoint: la red sigue sin contestar; rotando...'
                : '$endpoint: sesión rechazada; rotando...',
          );
          // Con la región rechazada, los otros puertos del mismo servidor
          // salen por la misma IP: se descartan.
          await rotate(endpoint, dropNode: region);
          continue;
        }
        sessionOk = true;
        final sessionTime = DateTime.now().difference(attemptStart);
        MoiamovApiService.logLine(
          '✅ Sesión de dispositivo obtenida (${sessionTime.inMilliseconds}ms).',
        );
        // El endpoint sirvió aunque después falle el catálogo: eso depende
        // del servidor del portal, no de la VPN.
        results.add((
          endpoint: endpoint,
          attempt: VpnAttempt.success,
          elapsed: sessionTime,
        ));

        if (!needsUpdate) break;
        await _downloadMissingSections(downloaded, showCancel: hasCatalog);
        if (_catalogCancelRequested) break;
        if (downloaded.length == _catalogSections.length) break;
        MoiamovApiService.logLine(
          'Faltan secciones (${downloaded.length}/${_catalogSections.length}); '
          'rotando...',
        );
        await rotate(endpoint);
      }

      // Si ningún túnel conectó, lo más probable es que no haya internet:
      // no es culpa de los endpoints y no se anota.
      if (anyTunnel) {
        await ranking.recordAll(results);
      } else if (results.isNotEmpty) {
        MoiamovApiService.logLine(
          'Ningún túnel conectó: el ranking no se modifica.',
        );
      }

      _setStep(_BootStep.ready, LocaleKeys.loading_secure_disconnecting);
      await vpn.disconnect();
      await _pause(const Duration(milliseconds: 300));

      // La fecha cambia solo con las 3 secciones: si falta alguna, el
      // próximo arranque vuelve a intentar.
      final complete = downloaded.length == _catalogSections.length;
      if (complete) await api.saveCatalogDate(DateTime.now());

      final String status;
      if (!sessionOk) {
        status = LocaleKeys.loading_session_failed;
      } else if (complete) {
        status = LocaleKeys.loading_catalog_updated;
      } else if (needsUpdate && !_catalogCancelRequested) {
        status = LocaleKeys.loading_catalog_not_updated;
      } else {
        status = LocaleKeys.loading_catalog_cached;
      }
      _setStep(_BootStep.ready, status);
      await _pause(const Duration(milliseconds: 1200));
    } catch (e) {
      MoiamovApiService.logLine('⚠️ Error en VPN, login o catálogo: $e');
      try {
        await vpn.disconnect();
      } catch (_) {}
    }

    final available = sessionOk ? await api.savedSections() : const <String>{};
    MoiamovApiService.logLine('Secciones disponibles: $available');
    if (mounted) {
      context.read<FeaturedMoviesProvider>().setAvailableSections(available);
    }
  }

  /// Baja las secciones que faltan: Películas primero, Destacados y Series juntas.
  Future<void> _downloadMissingSections(
    Set<String> downloaded, {
    required bool showCancel,
  }) async {
    if (!mounted) return;
    String progress() => LocaleKeys.loading_catalog_progress.tr(
      namedArgs: {
        'done': '${downloaded.length}',
        'total': '${_catalogSections.length}',
      },
    );
    _setStep(
      _BootStep.catalog,
      LocaleKeys.loading_catalog_downloading,
      detail: progress(),
    );
    setState(() => _catalogUpdateInProgress = showCancel);
    if (showCancel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _catalogUpdateInProgress) {
          _cancelCatalogFocus.requestFocus();
        }
      });
    }

    Future<void> download(String section) async {
      if (_catalogCancelRequested || downloaded.contains(section)) return;
      final result = await MoiamovApiService.instance.syncCatalog(
        section: section,
        timeout: const Duration(seconds: 12),
      );
      if (result.isFreshLive) {
        downloaded.add(section);
        _setDetail(progress());
      }
    }

    await download(FeaturedMoviesProvider.sectionMovies);
    await Future.wait([
      download(FeaturedMoviesProvider.sectionFeatured),
      download(FeaturedMoviesProvider.sectionSeries),
    ]);

    if (mounted) setState(() => _catalogUpdateInProgress = false);
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

  /// Mascota e isotipo de Moai.
  Widget _buildLogo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/moaiAbout.png',
          height: 112,
          cacheHeight: (112 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 14),
        SvgPicture.asset(
          'assets/svgs/appLogo.svg',
          height: 24,
          // Del mismo gris oscuro que el logo del Inicio.
          colorFilter: ColorFilter.mode(
            MoaiPalette.of(context).inkMuted,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }

  /// Recuadro de vidrio con la
  /// etapa, qué está haciendo y la barra de progreso en el acento.
  Widget _buildStatusCard(BuildContext context, ColorScheme scheme) {
    final showCancel = _catalogUpdateInProgress && !_catalogCancelRequested;
    return SizedBox(
      key: const ValueKey('loading_status'),
      width: 400,
      child: MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _icon,
                    key: ValueKey(_icon),
                    size: MoaiIconSizes.lg,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (_detailText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _detailText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.body(
                            context,
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: scheme.primary,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            if (showCancel) ...[
              const SizedBox(height: 18),
              Center(
                child: TvDialogButton(
                  focusNode: _cancelCatalogFocus,
                  label: _cancelCatalogLabel(),
                  icon: MoaiIcons.check,
                  autofocus: true,
                  onPressed: _cancelCatalogUpdate,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El mismo vidrio, con el aviso de error y el botón de reintento.
  Widget _buildErrorCard(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      key: const ValueKey('loading_error'),
      width: 420,
      child: MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.offline,
              size: MoaiIconSizes.xxl,
              color: scheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              LocaleKeys.loading_error_title.tr(),
              style: MoaiText.display(
                context,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? LocaleKeys.loading_error_connection.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TvDialogButton(
              focusNode: _retryFocusNode,
              label: LocaleKeys.update_action_retry.tr(),
              variant: TvDialogButtonVariant.primary,
              icon: MoaiIcons.refresh,
              onPressed: _startVerification,
            ),
          ],
        ),
      ),
    );
  }
}
