import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/vpn_service.dart';
import 'package:moai3/services/xuper_api_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:provider/provider.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
  String _statusText = 'loading_connecting'.tr();

  /// Origen final del catálogo usado en este arranque (para mostrarlo en pantalla).
  CatalogSource? _finalSource;
  int _finalMovieCount = 0;

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
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusText = 'loading_connecting'.tr();
      _finalSource = null;
      _finalMovieCount = 0;
    });

    XuperApiService.clearLog();
    XuperApiService.logLine('▶ Inicio de verificación de arranque Moai');

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

      // --- 1+2. Conectar VPN México y activar sesión; rotar nodo si falla ---
      bool vpnConnected = false;
      bool sessionOk = false;
      const int maxNodes = 4;

      for (int node = 0; node < maxNodes && !sessionOk; node++) {
        if (!mounted) break;
        setState(() {
          _statusText = 'Conectando a red segura México (nodo ${node + 1}/$maxNodes)...';
        });
        XuperApiService.logLine('VPN México: nodo ${node + 1}/$maxNodes');

        vpnConnected = await VpnService.instance.connectMexico(
          nodeIndex: node,
          timeout: const Duration(seconds: 14),
          onStatusUpdate: (msg) {
            if (mounted) setState(() => _statusText = msg);
          },
        );

        if (!vpnConnected) {
          XuperApiService.logLine('Nodo ${node + 1}: VPN no verificada como México.');
          vpnConnected = false;
          continue;
        }

        if (mounted) {
          setState(() => _statusText = 'Túnel seguro verificado (México)');
        }
        XuperApiService.logLine(
            'VPN conectada. Salida: ${VpnService.instance.lastExitIp} '
            '(${VpnService.instance.lastExitCountry})');
        // Esperar 2 segundos para estabilizar rutas y DNS de la interfaz tun0
        await Future.delayed(const Duration(milliseconds: 2000));

        if (mounted) {
          setState(() => _statusText = 'Iniciando sesión segura en Xuper...');
        }
        XuperApiService.logLine('Solicitando sesión de dispositivo (sin credenciales)...');
        sessionOk = await XuperApiService.instance.ensureSession();

        if (sessionOk) {
          XuperApiService.logLine('✅ Sesión de dispositivo obtenida.');
          break;
        }

        XuperApiService.logLine('Nodo ${node + 1}: sesión rechazada; rotando VPN...');
        await VpnService.instance.disconnect();
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      if (vpnConnected && sessionOk) {
        // --- 3. Descargar catálogo en vivo con la sesión ya activa ---
        for (int attempt = 1; attempt <= 3; attempt++) {
          if (!mounted) break;
          setState(() {
            _statusText = 'Descargando catálogo en vivo de Xuper (Intento $attempt de 3)...';
          });

          final catResult = await XuperApiService.instance.syncCatalog(
            section: 'masnew_movies',
            timeout: const Duration(seconds: 12),
          );

          if (mounted) {
            setState(() {
              _finalSource = catResult.source;
              _finalMovieCount = catResult.totalMovies;
            });
          }

          // Sincronizar también destacados y series de forma paralela garantizando que terminen antes de cerrar VPN
          await Future.wait([
            XuperApiService.instance.syncCatalog(section: 'masnew_featured', timeout: const Duration(seconds: 12)),
            XuperApiService.instance.syncCatalog(section: 'masnew_series', timeout: const Duration(seconds: 12)),
          ]);

          if (catResult.isFreshLive) {
            if (mounted) {
              setState(() {
                _statusText = 'Catálogo VIVO actualizado (${catResult.totalMovies} películas)';
              });
            }
            await Future.delayed(const Duration(milliseconds: 1500));
            break;
          } else if (catResult.categories.isNotEmpty) {
            // No vino en vivo (cache del TV o hardcodeado). No reintentar: informar claramente.
            if (mounted) {
              setState(() {
                _statusText = catResult.isHardcoded
                    ? 'Usando catálogo HARDCODEADO (${catResult.totalMovies} películas)'
                    : 'Catálogo desde cache del TV (${catResult.totalMovies} películas)';
              });
            }
            await Future.delayed(const Duration(milliseconds: 1500));
            break;
          } else {
            if (attempt < 3) {
              await Future.delayed(const Duration(milliseconds: 1000));
            }
          }
        }

        // --- 4. Desconectar VPN después de sincronizar ---
        if (mounted) {
          setState(() {
            _statusText = 'Desconectando red segura...';
          });
        }
        await VpnService.instance.disconnect();
        if (mounted) {
          setState(() {
            _statusText = 'Red segura desconectada';
          });
        }
        await Future.delayed(const Duration(milliseconds: 1000));
      } else {
        // Sin VPN y/o sin sesión: desconectar y cargar respaldo
        if (mounted) {
          setState(() {
            _statusText = 'Sin sesión en línea. Usando respaldo local...';
          });
        }
        await VpnService.instance.disconnect();
        await Future.delayed(const Duration(milliseconds: 1500));
        final fallback = await XuperApiService.instance.loadFallbackCatalog();
        if (mounted) {
          setState(() {
            _statusText = 'Catálogo de respaldo listo (${fallback.totalMovies} títulos)';
            _finalSource = fallback.source;
            _finalMovieCount = fallback.totalMovies;
          });
        }
        await Future.delayed(const Duration(milliseconds: 1500));
      }

      // Garantizar un tiempo mínimo total cinematográfico
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < const Duration(milliseconds: 1200)) {
        await Future.delayed(const Duration(milliseconds: 1200) - elapsed);
      }

      if (!mounted) return;

      setState(() {
        _statusText = _finalSource == CatalogSource.liveApi
            ? 'Listo. Catálogo EN VIVO aplicado.'
            : 'Listo. Iniciando Moai TV...';
      });
      // Dejar visible el resultado (fresco vs hardcodeado) antes de continuar.
      final holdMs = _finalSource == CatalogSource.liveApi
          ? 2500
          : (_finalSource == CatalogSource.localDocument ? 3500 : 6000);
      await Future.delayed(Duration(milliseconds: holdMs));

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
        // Badge tonal suave con estado
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 7,
                height: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusText,
                style: MoaiText.body(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSourceBanner(context, scheme),
        const SizedBox(height: 14),
        _buildLogPanel(context, scheme),
      ],
    );
  }

  /// Banner grande y persistente que indica si el catálogo es FRESCO (en vivo)
  /// o si se está usando el respaldo HARDCODEADO.
  Widget _buildSourceBanner(BuildContext context, ColorScheme scheme) {
    final src = _finalSource;
    final String text;
    final Color color;
    final IconData icon;
    switch (src) {
      case CatalogSource.liveApi:
        text = 'CATÁLOGO ACTUALIZADO EN VIVO · $_finalMovieCount títulos';
        color = const Color(0xFF43A047);
        icon = Icons.check_circle_rounded;
        break;
      case CatalogSource.localDocument:
        text = 'CATÁLOGO DESDE CACHE DEL TV (no en vivo) · $_finalMovieCount títulos';
        color = const Color(0xFFF9A825);
        icon = Icons.folder_special_rounded;
        break;
      case CatalogSource.assetBundle:
        text = '¡ATENCIÓN! USANDO CATÁLOGO HARDCODEADO · $_finalMovieCount títulos';
        color = scheme.error;
        icon = Icons.warning_amber_rounded;
        break;
      case null:
        text = 'Comprobando origen del catálogo...';
        color = scheme.onSurfaceVariant;
        icon = Icons.hourglass_top_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bitácora en pantalla con los pasos reales del arranque (VPN, sesión, API).
  Widget _buildLogPanel(BuildContext context, ColorScheme scheme) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: XuperApiService.liveLog,
      builder: (context, lines, _) {
        if (lines.isEmpty) return const SizedBox.shrink();
        final visible =
            lines.length > 9 ? lines.sublist(lines.length - 9) : lines;
        return Container(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 190),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: visible
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1.5),
                      child: Text(
                        l,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
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
            child: Icon(Icons.wifi_off_rounded, size: 38, color: scheme.error),
          ),
          const SizedBox(height: 18),
          Text(
            'Error de conexión',
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
            icon: Icons.refresh_rounded,
            onPressed: _startVerification,
          ),
        ],
      ),
    );
  }
}
