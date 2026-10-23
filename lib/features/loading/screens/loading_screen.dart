import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/config/app_info.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/vpn_service.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

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
  final FocusNode _cancelCatalogFocus = FocusNode(debugLabel: 'loading_cancel_catalog');

  bool _isLoading = true;
  String? _errorMessage;
  String _statusText = LocaleKeys.loading_connecting.tr();
  bool _catalogUpdateInProgress = false;
  bool _catalogCancelRequested = false;
  /// Invalida awaits en vuelo al cancelar o reiniciar sync.
  int _catalogRunId = 0;
  DateTime? _storedCatalogAt;

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

  void _cancelCatalogUpdate() {
    if (_catalogCancelRequested) return;
    _catalogRunId++;
    setState(() => _catalogCancelRequested = true);
    MoiamovApiService.instance.cancelActiveRequests();
    VpnService.instance.cancelConnect();
    VpnService.instance.disconnect();
  }

  bool _isCatalogRunCurrent(int runId) =>
      mounted && !_catalogCancelRequested && runId == _catalogRunId;

  String _cancelCatalogLabel() {
    final savedAt = _storedCatalogAt;
    if (savedAt == null) return LocaleKeys.loading_catalog_cancel_no_date.tr();
    final local = savedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final date = '$day/$month/${local.year}';
    return LocaleKeys.loading_catalog_cancel.tr(namedArgs: {'date': date});
  }

  Future<void> _loadSavedSections() async {
    await MoiamovApiService.instance.loadSavedOrBundled(section: 'masnew_movies');
    await MoiamovApiService.instance.loadSavedOrBundled();
    await MoiamovApiService.instance.loadSavedOrBundled(section: 'masnew_series');
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

      final tvSettings = context.read<TvSettingsProvider>();
      final skipCatalogUpdate = tvSettings.skipCatalogUpdate;
      final catalogSavedAt =
          await MoiamovApiService.instance.lastSavedCatalogAt();
      final frequencyAllows = TvSettingsProvider.shouldAttemptCatalogUpdate(
        savedAt: catalogSavedAt,
        frequency: tvSettings.catalogUpdateFrequency,
      );
      final shouldSyncCatalog = !skipCatalogUpdate && frequencyAllows;

      MoiamovApiService.logLine(
        'Catálogo arranque: skip=$skipCatalogUpdate '
        'freq=${tvSettings.catalogUpdateFrequency.storageValue} '
        'savedAt=${catalogSavedAt?.toIso8601String() ?? 'null'} '
        'frequencyAllows=$frequencyAllows → sync=$shouldSyncCatalog',
      );

      // Sin sync: skip → solo assets; frecuencia no vencida → último guardado o assets.
      if (!shouldSyncCatalog) {
        if (mounted) {
          setState(() => _statusText = LocaleKeys.loading_catalog_cached.tr());
        }
        if (skipCatalogUpdate) {
          MoiamovApiService.logLine('Catálogo de assets (actualizar apagado).');
          await MoiamovApiService.instance.loadFallbackCatalog(
            section: 'masnew_movies',
          );
          await MoiamovApiService.instance.loadFallbackCatalog(
            
          );
          await MoiamovApiService.instance.loadFallbackCatalog(
            section: 'masnew_series',
          );
        } else {
          MoiamovApiService.logLine(
            'Frecuencia aún no vencida '
            '(${tvSettings.catalogUpdateFrequency.storageValue}); '
            'usando última descarga o assets.',
          );
          await MoiamovApiService.instance.loadSavedOrBundled(
            section: 'masnew_movies',
          );
          await MoiamovApiService.instance.loadSavedOrBundled(
            
          );
          await MoiamovApiService.instance.loadSavedOrBundled(
            section: 'masnew_series',
          );
        }
      } else {
      MoiamovApiService.instance.beginCatalogSync();
      VpnService.instance.resetConnectCancellation();
      final catalogRunId = ++_catalogRunId;
      _catalogCancelRequested = false;
      _storedCatalogAt = await MoiamovApiService.instance.lastSavedCatalogAt();
      if (_isCatalogRunCurrent(catalogRunId)) {
        setState(() {
          _catalogUpdateInProgress = true;
          _statusText = LocaleKeys.loading_secure_connecting.tr();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isCatalogRunCurrent(catalogRunId)) {
            _cancelCatalogFocus.requestFocus();
          }
        });
      }
      // --- 1+2. VPN (permiso dentro de connect) + sesión; rotar nodo si falla ---
      bool vpnConnected = false;
      bool sessionOk = false;
      const int maxNodes = 4;

      void onVpnStatus(String key) {
        if (_isCatalogRunCurrent(catalogRunId)) {
          setState(() => _statusText = key.tr());
        }
      }

      // El permiso VPN se pide dentro de connectMexico (el plugin guarda la
      // config, muestra el aviso del SO y al OK arranca el túnel). No usar
      // requestPermissionAndroid aparte: devuelve false al mostrar el diálogo.
      MoiamovApiService.logLine('Iniciando flujo VPN + sync de catálogo...');

      for (int node = 0;
          _isCatalogRunCurrent(catalogRunId) &&
              node < maxNodes &&
              !sessionOk;
          node++) {
        setState(() {
          _statusText = LocaleKeys.loading_secure_connecting.tr();
        });
        MoiamovApiService.logLine('Nodo ${node + 1}/$maxNodes');

        vpnConnected = await VpnService.instance.connectMexico(
          nodeIndex: node,
          onStatusUpdate: onVpnStatus,
        );

        if (!_isCatalogRunCurrent(catalogRunId)) break;

        if (!vpnConnected) {
          MoiamovApiService.logLine('Nodo ${node + 1}: conexión no verificada.');
          vpnConnected = false;
          continue;
        }

        if (_isCatalogRunCurrent(catalogRunId)) {
          setState(() => _statusText = LocaleKeys.loading_secure_verified.tr());
        }
        MoiamovApiService.logLine(
            'Conexión lista. Salida: ${VpnService.instance.lastExitIp} '
            '(${VpnService.instance.lastExitCountry})');
        // Esperar 2 segundos para estabilizar rutas y DNS de la interfaz tun0
        await _pause(const Duration(milliseconds: 2000));
        if (!_isCatalogRunCurrent(catalogRunId)) break;

        if (_isCatalogRunCurrent(catalogRunId)) {
          setState(() => _statusText = LocaleKeys.loading_session_init.tr());
        }
        MoiamovApiService.logLine('Solicitando sesión de dispositivo (sin credenciales)...');
        sessionOk = await MoiamovApiService.instance.ensureSession();
        if (!_isCatalogRunCurrent(catalogRunId)) break;

        if (sessionOk) {
          MoiamovApiService.logLine('✅ Sesión de dispositivo obtenida.');
          break;
        }

        MoiamovApiService.logLine('Nodo ${node + 1}: sesión rechazada; rotando nodo...');
        await VpnService.instance.disconnect();
        await _pause(const Duration(milliseconds: 1500));
      }

      if (_isCatalogRunCurrent(catalogRunId) && vpnConnected && sessionOk) {
        // --- 3. Descargar catálogo en vivo con la sesión ya activa ---
        for (int attempt = 1; attempt <= 3; attempt++) {
          if (!_isCatalogRunCurrent(catalogRunId)) break;
          setState(() {
            _statusText = LocaleKeys.loading_catalog_downloading.tr();
          });

          final catResult = await MoiamovApiService.instance.syncCatalog(
            timeout: const Duration(seconds: 12),
          );

          // Sincronizar también destacados y series de forma paralela garantizando que terminen antes de cerrar VPN
          if (_isCatalogRunCurrent(catalogRunId)) {
            await Future.wait([
              MoiamovApiService.instance.syncCatalog(section: 'masnew_featured', timeout: const Duration(seconds: 12)),
              MoiamovApiService.instance.syncCatalog(section: 'masnew_series', timeout: const Duration(seconds: 12)),
            ]);
          }
          if (!_isCatalogRunCurrent(catalogRunId)) break;

          if (catResult.isFreshLive) {
            if (_isCatalogRunCurrent(catalogRunId)) {
              setState(() {
                _statusText = LocaleKeys.loading_catalog_updated.tr();
              });
            }
            await _pause(const Duration(milliseconds: 1200));
            break;
          } else if (catResult.categories.isNotEmpty) {
            // No vino en vivo (cache del TV o hardcodeado). No reintentar: informar claramente.
            if (_isCatalogRunCurrent(catalogRunId)) {
              setState(() {
                _statusText = catResult.isHardcoded
                    ? LocaleKeys.loading_catalog_fallback.tr()
                    : LocaleKeys.loading_catalog_cached.tr();
              });
            }
            await _pause(const Duration(milliseconds: 1200));
            break;
          } else {
            if (attempt < 3 && _isCatalogRunCurrent(catalogRunId)) {
              await _pause(const Duration(milliseconds: 1000));
            }
          }
        }

        // --- 4. Desconectar servicio de fondo después de sincronizar ---
        if (_isCatalogRunCurrent(catalogRunId)) {
          setState(() {
            _statusText = LocaleKeys.loading_secure_disconnecting.tr();
          });
        }
        await VpnService.instance.disconnect();
        if (_isCatalogRunCurrent(catalogRunId)) {
          await _pause(const Duration(milliseconds: 1000));
        }
      } else if (_isCatalogRunCurrent(catalogRunId)) {
        // Sin VPN y/o sin sesión: desconectar y cargar respaldo
        setState(() {
          _statusText = LocaleKeys.loading_catalog_fallback.tr();
        });
        await VpnService.instance.disconnect();
        await _pause(const Duration(milliseconds: 1500));
        if (_isCatalogRunCurrent(catalogRunId)) {
          final movies = await MoiamovApiService.instance.loadSavedOrBundled(
            section: 'masnew_movies',
          );
          await MoiamovApiService.instance.loadSavedOrBundled(
            
          );
          await MoiamovApiService.instance.loadSavedOrBundled(
            section: 'masnew_series',
          );
          if (_isCatalogRunCurrent(catalogRunId)) {
            setState(() {
              _statusText = movies.isHardcoded
                  ? LocaleKeys.loading_catalog_fallback.tr()
                  : LocaleKeys.loading_catalog_cached.tr();
            });
          }
          await _pause(const Duration(milliseconds: 1200));
        }
      }

      if (_catalogCancelRequested) {
        MoiamovApiService.logLine('Actualización cancelada. Se usa el catálogo guardado.');
        await VpnService.instance.disconnect();
        await _loadSavedSections();
      }
      if (mounted) {
        setState(() => _catalogUpdateInProgress = false);
      }
      }

      if (_catalogCancelRequested) {
        if (!mounted) return;
      } else {
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
      }

      if (!mounted) return;

      // Dispositivo activo -> Ir a Overlap, NicknameSetup o Home
      final effectiveNick =
          (record.nickname != null && record.nickname!.trim().isNotEmpty)
          ? record.nickname!.trim()
          : (localNickname != null && localNickname.trim().isNotEmpty
                ? localNickname.trim()
                : widget.identityService.getNickname()?.trim());

      if (!tvSettings.hasOverlapConfig) {
        context.go('/overlap');
      } else if (effectiveNick == null || effectiveNick.isEmpty) {
        context.go('/nickname_setup');
      } else {
        context.go('/home');
      }
    } on TimeoutException {
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
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: scheme.surface,
              gradient: RadialGradient(
                radius: 0.95,
                colors: [
                  scheme.primary.withValues(alpha: _glowAnimation.value),
                  scheme.surfaceContainerLowest.withValues(alpha: 0.2),
                  scheme.surface,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/fondo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
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
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Transform.scale(
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
              // Mascota e Isotipo de Moai
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/moaiAbout.png',
                    height: 112,
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
            ],
          ),
        ),
        const SizedBox(height: 38),
        // Indicador de píldora expresiva (Material 3 Expressive Pill)
        Container(
          width: 160,
          height: 4.5,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
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
        // Píldora de estado estilo MoaiSnackBar (color plano, sin sombra)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.tertiary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusText,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onTertiary,
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
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(MoaiIcons.wifiOffRounded, size: 38, color: scheme.error),
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
            icon: MoaiIcons.refreshRounded,
            onPressed: _startVerification,
          ),
        ],
      ),
    );
  }
}
