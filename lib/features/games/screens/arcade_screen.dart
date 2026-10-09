import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/widgets/arcade_controller_overlay.dart';
import 'package:moai3/features/games/widgets/arcade_view_container.dart';

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
  final bool _showOverlay = false;
  bool _isLoading = false;

  static const String _defaultRomPath = '/data/user/0/com.infomak.moai/files/mvsc.zip';
  static const MethodChannel _tvPlayerChannel = MethodChannel('com.infomak.moai.tv/player');

  @override
  void initState() {
    super.initState();
    // Pausar cualquier transmisión de TV activa para liberar decodificadores y CPU
    _tvPlayerChannel.invokeMethod<void>('pauseAll');
    _initEmulator();
  }

  Future<void> _initEmulator() async {
    setState(() => _isLoading = true);
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
    _emulatorService.stop();
    // Reanudar la transmisión de TV al salir del Arcade
    _tvPlayerChannel.invokeMethod<void>('resumeAll');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: FocusScope(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.goBack ||
               event.logicalKey == LogicalKeyboardKey.escape ||
               event.logicalKey == LogicalKeyboardKey.backspace)) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
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

          // 3. Botón de volver superior
          Positioned(
            top: 12,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => Navigator.pop(context),
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
