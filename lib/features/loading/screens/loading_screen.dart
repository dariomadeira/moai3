import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/config/player_config.dart';
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
  String _statusText = 'loading_connecting'.tr();
  bool _catalogUpdateInProgress = false;
  bool _catalogCancelRequested = false;
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
    setState(() => _catalogCancelRequested = true);
    MoiamovApiService.instance.cancelActiveRequests();
    VpnService.instance.cancelConnect();
    VpnService.instance.disconnect();
  }

  String _cancelCatalogLabel() {
    final savedAt = _storedCatalogAt;
    if (savedAt == null) return 'loading_catalog_cancel_no_date'.tr();
    final local = savedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final date = '$day/$month/${local.year}';
    return 'loading_catalog_cancel'.tr(namedArgs: {'date': date});
  }

  Future<void> _loadSavedSections() async {
    await MoiamovApiService.instance.loadSavedOrBundled(section: 'masnew_movies');
    await MoiamovApiService.instance.loadSavedOrBundled(section: 'masnew_featured');
    await MoiamovApiService.instance.loadSavedOrBundled(section: 'masnew_series');
  }

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'loading_connecting'.tr();
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

      try {
        final watchParty = context.read<WatchPartyProvider>();
        if (record.userCode != null) {
          watchParty.updateUserCode(record.userCode!);
        }
      } catch (_) {}

      // Si el dispositivo está bloqueado (RB-04 / CASO-UC-02)
      if (!record.isActive) {
        context.go('/blocked', extra: record.blockReason);
        return;
      }

      final skipCatalogUpdate =
          context.read<TvSettingsProvider>().skipCatalogUpdate;

      // Catálogo incluido: no conectar ni descargar.
      if (skipCatalogUpdate) {
        if (mounted) {
          setState(() => _statusText = 'loading_catalog_cached'.tr());
        }
        MoiamovApiService.logLine('Catálogo incluido, sin actualización.');
        await MoiamovApiService.instance.loadFallbackCatalog(
          section: 'masnew_movies',
        );
        await MoiamovApiService.instance.loadFallbackCatalog(
          section: 'masnew_featured',
        );
        await MoiamovApiService.instance.loadFallbackCatalog(
          section: 'masnew_series',
        );
      } else {
      MoiamovApiService.instance.beginCatalogSync();
      _catalogCancelRequested = false;
      _storedCatalogAt = await MoiamovApiService.instance.lastSavedCatalogAt();
      if (mounted) {
        setState(() => _catalogUpdateInProgress = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_catalogCancelRequested) {
            _cancelCatalogFocus.requestFocus();
          }
        });
      }
      // --- 1+2. Conectar servicio de fondo y activar sesión; rotar nodo si falla ---
      bool vpnConnected = false;
      bool sessionOk = false;
      const int maxNodes = 4;

      for (int node = 0; node < maxNodes && !sessionOk; node++) {
        if (!mounted || _catalogCancelRequested) break;
        setState(() {
          _statusText = 'loading_secure_connecting'.tr();
        });
        MoiamovApiService.logLine('Nodo ${node + 1}/$maxNodes');

        vpnConnected = await VpnService.instance.connectMexico(
          nodeIndex: node,
          timeout: const Duration(seconds: 14),
          onStatusUpdate: (key) {
            if (mounted && !_catalogCancelRequested) {
              setState(() => _statusText = key.tr());
            }
          },
        );

        if (_catalogCancelRequested) break;

        if (!vpnConnected) {
          MoiamovApiService.logLine('Nodo ${node + 1}: conexión no verificada.');
          vpnConnected = false;
          continue;
        }

        if (mounted) {
          setState(() => _statusText = 'loading_secure_verified'.tr());
        }
        MoiamovApiService.logLine(
            'Conexión lista. Salida: ${VpnService.instance.lastExitIp} '
            '(${VpnService.instance.lastExitCountry})');
        // Esperar 2 segundos para estabilizar rutas y DNS de la interfaz tun0
        await _pause(const Duration(milliseconds: 2000));
        if (_catalogCancelRequested) break;

        if (mounted) {
          setState(() => _statusText = 'loading_session_init'.tr());
        }
        MoiamovApiService.logLine('Solicitando sesión de dispositivo (sin credenciales)...');
        sessionOk = await MoiamovApiService.instance.ensureSession();
        if (_catalogCancelRequested) break;

        if (sessionOk) {
          MoiamovApiService.logLine('✅ Sesión de dispositivo obtenida.');
          break;
        }

        MoiamovApiService.logLine('Nodo ${node + 1}: sesión rechazada; rotando nodo...');
        await VpnService.instance.disconnect();
        await _pause(const Duration(milliseconds: 1500));
      }

      if (!_catalogCancelRequested && vpnConnected && sessionOk) {
        // --- 3. Descargar catálogo en vivo con la sesión ya activa ---
        for (int attempt = 1; attempt <= 3; attempt++) {
          if (!mounted || _catalogCancelRequested) break;
          setState(() {
            _statusText = 'loading_catalog_downloading'.tr();
          });

          final catResult = await MoiamovApiService.instance.syncCatalog(
            section: 'masnew_movies',
            timeout: const Duration(seconds: 12),
          );

          // Sincronizar también destacados y series de forma paralela garantizando que terminen antes de cerrar VPN
          if (!_catalogCancelRequested) {
            await Future.wait([
              MoiamovApiService.instance.syncCatalog(section: 'masnew_featured', timeout: const Duration(seconds: 12)),
              MoiamovApiService.instance.syncCatalog(section: 'masnew_series', timeout: const Duration(seconds: 12)),
            ]);
          }
          if (_catalogCancelRequested) break;

          if (catResult.isFreshLive) {
            if (mounted) {
              setState(() {
                _statusText = 'loading_catalog_updated'.tr();
              });
            }
            await _pause(const Duration(milliseconds: 1200));
            break;
          } else if (catResult.categories.isNotEmpty) {
            // No vino en vivo (cache del TV o hardcodeado). No reintentar: informar claramente.
            if (mounted) {
              setState(() {
                _statusText = catResult.isHardcoded
                    ? 'loading_catalog_fallback'.tr()
                    : 'loading_catalog_cached'.tr();
              });
            }
            await _pause(const Duration(milliseconds: 1200));
            break;
          } else {
            if (attempt < 3 && !_catalogCancelRequested) {
              await _pause(const Duration(milliseconds: 1000));
            }
          }
        }

        // --- 4. Desconectar servicio de fondo después de sincronizar ---
        if (!_catalogCancelRequested && mounted) {
          setState(() {
            _statusText = 'loading_secure_disconnecting'.tr();
          });
        }
        await VpnService.instance.disconnect();
        if (!_catalogCancelRequested) {
          await _pause(const Duration(milliseconds: 1000));
        }
      } else if (!_catalogCancelRequested) {
        // Sin VPN y/o sin sesión: desconectar y cargar respaldo
        if (mounted) {
          setState(() {
            _statusText = 'loading_catalog_fallback'.tr();
          });
        }
        await VpnService.instance.disconnect();
        await _pause(const Duration(milliseconds: 1500));
        final movies = await MoiamovApiService.instance.loadSavedOrBundled(
          section: 'masnew_movies',
        );
        await MoiamovApiService.instance.loadSavedOrBundled(
          section: 'masnew_featured',
        );
        await MoiamovApiService.instance.loadSavedOrBundled(
          section: 'masnew_series',
        );
        if (mounted) {
          setState(() {
            _statusText = movies.isHardcoded
                ? 'loading_catalog_fallback'.tr()
                : 'loading_catalog_cached'.tr();
          });
        }
        await _pause(const Duration(milliseconds: 1200));
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
        _statusText = 'loading_ready'.tr();
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      }

      if (!mounted) return;

      // Dispositivo activo -> Ir a Overlap, NicknameSetup o Home
      final tvSettings = context.read<TvSettingsProvider>();
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
        _errorMessage = 'loading_error_connection'.tr();
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
        _errorMessage = 'loading_error_connection'.tr();
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
                center: Alignment.center,
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
                      'v${PlayerConfig.appVersion}',
                      style: MoaiText.body(
                        context,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w600,
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
              fontWeight: FontWeight.w600,
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
            variant: TvDialogButtonVariant.neutral,
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
            'loading_error_title'.tr(),
            style: MoaiText.display(
              context,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'loading_error_connection'.tr(),
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
            label: 'update_action_retry'.tr(),
            variant: TvDialogButtonVariant.primary,
            icon: MoaiIcons.refreshRounded,
            onPressed: _startVerification,
          ),
        ],
      ),
    );
  }
}
