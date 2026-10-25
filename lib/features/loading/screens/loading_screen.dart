import 'dart:async';
import 'package:moai3/config/constants.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
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

/// Pantalla inicial de verificación de presencia y carga con estética Material 3 Expressive (SPEC-22 §4.1).
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
  final FocusNode _retryFocusNode = FocusNode(debugLabel: 'loading_retry');
  final FocusNode _cancelCatalogFocus = FocusNode(
    debugLabel: 'loading_cancel_catalog',
  );

  bool _isLoading = true;
  String? _errorMessage;
  String _statusText = LocaleKeys.loading_connecting.tr();
  bool _catalogUpdateInProgress = false;
  bool _catalogCancelRequested = false;
  DateTime? _storedCatalogAt;

  /// Intentos de VPN + login + descarga, cada uno con otro nodo.
  static const int _maxAttempts = 3;

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

    _glowAnimation = Tween<double>(begin: 0.12, end: 0.28).animate(
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
    if (mounted) setState(() => _statusText = key.tr());
  }

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
      _statusText = LocaleKeys.loading_connecting.tr();
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

        // Garantizar un tiempo mínimo total cinematográfico
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < const Duration(milliseconds: 1200)) {
          await Future.delayed(const Duration(milliseconds: 1200) - elapsed);
        }

        if (!mounted) return;

        setState(() {
          _statusText = LocaleKeys.loading_ready.tr();
        });
        await Future.delayed(const Duration(milliseconds: 1200));
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
    } on TimeoutException catch (e) {
      MoiamovApiService.logLine('❌ Verificación del dispositivo: $e');
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
    } catch (e, st) {
      MoiamovApiService.logLine('❌ Verificación del dispositivo: $e\n$st');
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

      // Los nodos van en el orden del ranking (SPEC-39 §4.1); los
      // resultados se anotan al final.
      final ranking = VpnNodeRanking();
      final nodes = (await ranking.orderedNodes()).take(_maxAttempts).toList();
      final results = <({VpnNode node, bool success, Duration? elapsed})>[];
      var anyTunnel = false;

      // El permiso VPN se pide dentro de connect (el plugin guarda la
      // config, muestra el aviso del SO y al OK arranca el túnel). No usar
      // requestPermissionAndroid aparte: devuelve false al mostrar el diálogo.
      for (var attempt = 0; attempt < nodes.length && mounted; attempt++) {
        final node = nodes[attempt];
        final attemptStart = DateTime.now();
        _setStatus(LocaleKeys.loading_secure_connecting);
        MoiamovApiService.logLine(
          'Intento ${attempt + 1}/${nodes.length}: ${node.id}',
        );

        final connection = await vpn.connect(node, onStatusUpdate: _setStatus);
        if (connection == VpnConnectResult.permissionDenied) {
          MoiamovApiService.logLine('Permiso VPN rechazado por el usuario.');
          break;
        }
        if (connection == VpnConnectResult.cancelled) break;
        if (connection != VpnConnectResult.connected) {
          if (connection == VpnConnectResult.wrongCountry) anyTunnel = true;
          results.add((node: node, success: false, elapsed: null));
          MoiamovApiService.logLine(
            '${node.id}: conexión no verificada ($connection).',
          );
          await vpn.disconnect();
          await _pause(const Duration(milliseconds: 1500));
          continue;
        }
        anyTunnel = true;

        _setStatus(LocaleKeys.loading_secure_verified);
        MoiamovApiService.logLine(
          'Conexión lista. Salida: ${vpn.lastExitIp} (${vpn.lastExitCountry})',
        );
        // Esperar 2 segundos para estabilizar rutas y DNS de la interfaz tun0
        await _pause(const Duration(milliseconds: 2000));

        _setStatus(LocaleKeys.loading_session_init);
        MoiamovApiService.logLine(
          'Solicitando sesión de dispositivo (sin credenciales)...',
        );
        if (!await api.ensureSession()) {
          results.add((node: node, success: false, elapsed: null));
          MoiamovApiService.logLine(
            '${node.id}: sesión rechazada; rotando nodo...',
          );
          await vpn.disconnect();
          await _pause(const Duration(milliseconds: 1500));
          continue;
        }
        sessionOk = true;
        final sessionTime = DateTime.now().difference(attemptStart);
        MoiamovApiService.logLine('✅ Sesión de dispositivo obtenida.');

        if (!needsUpdate) {
          results.add((node: node, success: true, elapsed: sessionTime));
          break;
        }
        await _downloadMissingSections(downloaded, showCancel: hasCatalog);
        // Si el usuario cortó la descarga, este nodo no se anota.
        if (_catalogCancelRequested) break;
        final complete = downloaded.length == _catalogSections.length;
        results.add((node: node, success: complete, elapsed: sessionTime));
        if (complete) break;
        MoiamovApiService.logLine(
          'Faltan secciones (${downloaded.length}/${_catalogSections.length}); '
          'rotando nodo...',
        );
        await vpn.disconnect();
        await _pause(const Duration(milliseconds: 1500));
      }

      // Si ningún túnel conectó, lo más probable es que no haya internet:
      // no es culpa de los nodos y no se anota.
      if (anyTunnel) {
        for (final r in results) {
          await ranking.record(r.node, success: r.success, elapsed: r.elapsed);
        }
      } else if (results.isNotEmpty) {
        MoiamovApiService.logLine(
          'Ningún túnel conectó: el ranking no se modifica.',
        );
      }

      _setStatus(LocaleKeys.loading_secure_disconnecting);
      await vpn.disconnect();
      await _pause(const Duration(milliseconds: 1000));

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
      _setStatus(status);
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
    setState(() {
      _catalogUpdateInProgress = showCancel;
      _statusText = LocaleKeys.loading_catalog_downloading.tr();
    });
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
      if (result.isFreshLive) downloaded.add(section);
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
      backgroundColor: scheme.surface,
      // El fondo es el ambiente (estático); sólo el logo late con la
      // animación (SPEC-50 §6.1). El viejo degradado pulsante quedaba tapado
      // por el ambiente y repintaba la pantalla entera en cada frame.
      body: SizedBox.expand(
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: MoaiAmbientBackground()),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: _isLoading
                    ? _buildLoadingState(context, scheme)
                    : _buildErrorState(context, scheme),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v${AppInfo.version}',
                  style: MoaiText.body(
                    context,
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, logo) => Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Aura de luz ambiental circular difuminada
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: _glowAnimation.value,
                        ),
                        blurRadius: 48,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                ),
                logo!,
              ],
            ),
          ),
          // Mascota e Isotipo de Moai
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/moaiAbout.png',
                height: 112,
                cacheHeight: (112 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              SvgPicture.asset(
                'assets/svgs/appLogo.svg',
                height: 24,
                colorFilter: ColorFilter.mode(
                  scheme.onSurface,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 38),
        // Indicador de píldora expresiva (Material 3 Expressive Pill)
        Container(
          width: 160,
          height: 4.5,
          // Riel de cristal: una línea tenue, sin relleno opaco.
          decoration: BoxDecoration(
            color:
                (scheme.brightness == Brightness.dark
                        ? Colors.white
                        : scheme.onSurface)
                    .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(100),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              color: scheme.primary,
              backgroundColor: Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Píldora de estado: chip de cristal teñido del acento.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: moaiGlassChipDecoration(scheme, highlighted: true),
          child: Text(
            _statusText,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (_catalogUpdateInProgress && !_catalogCancelRequested) ...[
          const SizedBox(height: 22),
          TvDialogButton(
            focusNode: _cancelCatalogFocus,
            label: _cancelCatalogLabel(),
            autofocus: true,
            onPressed: _cancelCatalogUpdate,
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, ColorScheme scheme) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      // Misma superficie que los diálogos sobre el fondo ambiente.
      decoration: moaiDialogDecoration(scheme, radius: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              MoaiIcons.offline,
              size: MoaiIconSizes.xxl,
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            LocaleKeys.loading_error_title.tr(),
            style: MoaiText.display(
              context,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? LocaleKeys.loading_error_connection.tr(),
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TvDialogButton(
            focusNode: _retryFocusNode,
            label: LocaleKeys.update_action_retry.tr(),
            variant: TvDialogButtonVariant.primary,
            icon: MoaiIcons.refresh,
            onPressed: _startVerification,
          ),
        ],
      ),
    );
  }
}
