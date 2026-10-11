import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/widgets/arcade_controller_overlay.dart';
import 'package:moai3/features/games/widgets/arcade_view_container.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla principal para emular y jugar juegos de Arcade (FBNeo / Libretro).
class ArcadeScreen extends StatefulWidget {
  final String? initialRomPath;

  const ArcadeScreen({
    super.key,
    this.initialRomPath,
  });

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  final ArcadeEmulatorService _emulatorService = ArcadeEmulatorService();
  final FocusNode _gamepadFocusNode = FocusNode(debugLabel: 'arcade_gamepad');
  final bool _showOverlay = false;
  bool _isLoading = false;
  int _activeInputMask = 0;
  String? _gamepadNotification;
  Timer? _gamepadToastTimer;
  StreamSubscription<void>? _exitSubscription;
  StreamSubscription<int>? _gamepadSubscription;
  bool _isExiting = false;
  final Set<int> _notifiedPlayers = {};

  static const String _defaultRomPath = '/data/user/0/com.infomak.moai/files/mvsc.zip';
  static const MethodChannel _tvPlayerChannel = MethodChannel('com.infomak.moai.tv/player');

  @override
  void initState() {
    super.initState();
    // Pausar cualquier transmisión de TV activa para liberar decodificadores y CPU
    _tvPlayerChannel.invokeMethod<void>('pauseAll');

    _exitSubscription = _emulatorService.onRequestExit.listen((_) {
      if (!_isExiting && mounted && Navigator.of(context).canPop()) {
        _isExiting = true;
        Navigator.of(context).pop();
      }
    });

    _gamepadSubscription = _emulatorService.onGamepadAssigned.listen((player) {
      if (mounted && !_notifiedPlayers.contains(player)) {
        _notifiedPlayers.add(player);
        final message = player == 1
            ? '🎮 Mando 2 detectado - ¡Jugador 2 listo!'
            : '🎮 Mando 1 detectado - Jugador 1';
        _showGamepadToast(message);
      }
    });

    _initEmulator();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _gamepadFocusNode.requestFocus();
      }
    });
  }

  void _showGamepadToast(String message) {
    _gamepadToastTimer?.cancel();
    setState(() {
      _gamepadNotification = message;
    });
    _gamepadToastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _gamepadNotification = null;
        });
      }
    });
  }

  Future<void> _initEmulator() async {
    setState(() => _isLoading = true);
    final corePath = ArcadePluginService.instance.installedCorePath;
    if (corePath != null && corePath.isNotEmpty) {
      await _emulatorService.setCustomCorePath(corePath);
    }
    await _emulatorService.initializeEmulator();
    final String romToLoad = widget.initialRomPath ?? _defaultRomPath;
    if (romToLoad.isNotEmpty) {
      await _emulatorService.loadRom(romToLoad);
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _exitSubscription?.cancel();
    _gamepadSubscription?.cancel();
    _gamepadToastTimer?.cancel();
    _gamepadFocusNode.dispose();
    _emulatorService.stop();
    _emulatorService.dispose();
    // Reanudar la transmisión de TV al salir del Arcade
    _tvPlayerChannel.invokeMethod<void>('resumeAll');
    super.dispose();
  }

  KeyEventResult _handleGamepadKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Permitir salir con Tecla Back / Escape
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.goBack ||
         key == LogicalKeyboardKey.escape ||
         key == LogicalKeyboardKey.backspace)) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      }
    }

    int bit = 0;

    // 1. D-Pad y Direcciones
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.gameButton11 ||
        key == LogicalKeyboardKey.keyW) {
      bit = ArcadeButtons.up;
    } else if (key == LogicalKeyboardKey.arrowDown ||
               key == LogicalKeyboardKey.gameButton12 ||
               key == LogicalKeyboardKey.keyS) {
      bit = ArcadeButtons.down;
    } else if (key == LogicalKeyboardKey.arrowLeft ||
               key == LogicalKeyboardKey.gameButton13 ||
               key == LogicalKeyboardKey.keyA) {
      bit = ArcadeButtons.left;
    } else if (key == LogicalKeyboardKey.arrowRight ||
               key == LogicalKeyboardKey.gameButton14 ||
               key == LogicalKeyboardKey.keyD) {
      bit = ArcadeButtons.right;
    }
    // 2. COIN y START
    else if (key == LogicalKeyboardKey.gameButtonSelect ||
               key == LogicalKeyboardKey.gameButton8 ||
               key == LogicalKeyboardKey.gameButton9 ||
               key == LogicalKeyboardKey.digit9 ||
               key == LogicalKeyboardKey.space ||
               key == LogicalKeyboardKey.keyC) {
      bit = ArcadeButtons.coin;
    } else if (key == LogicalKeyboardKey.gameButtonStart ||
               key == LogicalKeyboardKey.gameButton7 ||
               key == LogicalKeyboardKey.gameButton10 ||
               key == LogicalKeyboardKey.digit1 ||
               key == LogicalKeyboardKey.enter ||
               key == LogicalKeyboardKey.keyV) {
      bit = ArcadeButtons.start;
    }
    // 3. Botones de Ataque Arcade CPS-2 (6 botones)
    else if (key == LogicalKeyboardKey.gameButtonX ||
               key == LogicalKeyboardKey.gameButton3 ||
               key == LogicalKeyboardKey.keyU) {
      bit = ArcadeButtons.punchLight; // LP
    } else if (key == LogicalKeyboardKey.gameButtonY ||
               key == LogicalKeyboardKey.gameButton4 ||
               key == LogicalKeyboardKey.keyI) {
      bit = ArcadeButtons.punchMedium; // MP
    } else if (key == LogicalKeyboardKey.gameButtonRight1 ||
               key == LogicalKeyboardKey.gameButtonLeft1 ||
               key == LogicalKeyboardKey.gameButton5 ||
               key == LogicalKeyboardKey.keyO) {
      bit = ArcadeButtons.punchHeavy; // HP
    } else if (key == LogicalKeyboardKey.gameButtonA ||
               key == LogicalKeyboardKey.gameButton1 ||
               key == LogicalKeyboardKey.gameButton2 ||
               key == LogicalKeyboardKey.keyJ) {
      bit = ArcadeButtons.kickLight; // LK
    } else if (key == LogicalKeyboardKey.gameButtonB ||
               key == LogicalKeyboardKey.gameButton6 ||
               key == LogicalKeyboardKey.keyK) {
      bit = ArcadeButtons.kickMedium; // MK
    } else if (key == LogicalKeyboardKey.gameButtonRight2 ||
               key == LogicalKeyboardKey.gameButtonLeft2 ||
               key == LogicalKeyboardKey.gameButton7 ||
               key == LogicalKeyboardKey.keyL) {
      bit = ArcadeButtons.kickHeavy; // HK
    }

    if (bit != 0) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _activeInputMask |= bit;
      } else if (event is KeyUpEvent) {
        _activeInputMask &= ~bit;
      }
      _emulatorService.sendInputMask(_activeInputMask);

      // Salir si se pulsa la combinación SELECT + START simultáneamente
      final isCoin = (_activeInputMask & ArcadeButtons.coin) != 0;
      final isStart = (_activeInputMask & ArcadeButtons.start) != 0;
      if (isCoin && isStart && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final double overlapX = () {
      try {
        return context.select((TvSettingsProvider s) => s.overlapPaddingX);
      } catch (_) {
        return 20.0;
      }
    }();
    final double overlapY = () {
      try {
        return context.select((TvSettingsProvider s) => s.overlapPaddingY);
      } catch (_) {
        return 20.0;
      }
    }();

    return PopScope(
      canPop: true,
      child: Focus(
        focusNode: _gamepadFocusNode,
        autofocus: true,
        onKeyEvent: _handleGamepadKeyEvent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 1. Vista de Video del Emulador (AndroidView SurfaceView)
              const Positioned.fill(
                child: ArcadeViewContainer(),
              ),

              // 2. Controles táctiles overlay
              Positioned.fill(
                child: ArcadeControllerOverlay(
                  service: _emulatorService,
                  showControls: _showOverlay,
                ),
              ),

              // 3. Botón de volver superior alineado con el overscan del usuario
              Positioned(
                top: overlapY + 8,
                left: overlapX + 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // Notificación de mando / jugador conectado
              if (_gamepadNotification != null)
                Positioned(
                  top: overlapY + 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.cyanAccent.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sports_esports, color: Colors.cyanAccent, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _gamepadNotification!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Indicador de Carga
              if (_isLoading)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.cyanAccent),
                        const SizedBox(height: 16),
                        Text(
                          'arcade_loading_engine'.tr(),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
