import 'package:flutter/material.dart';
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
  final TextEditingController _pathController = TextEditingController();
  bool _showOverlay = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.initialRomPath ?? '/sdcard/roms/mvsc.zip';
    _initEmulator();
  }

  Future<void> _initEmulator() async {
    setState(() => _isLoading = true);
    await _emulatorService.initializeEmulator();
    if (widget.initialRomPath != null && widget.initialRomPath!.isNotEmpty) {
      await _emulatorService.loadRom(widget.initialRomPath!);
    }
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _pathController.dispose();
    _emulatorService.stop();
    super.dispose();
  }

  void _showLoadRomDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Cargar ROM de Arcade',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingresa la ruta absoluta del archivo .zip (ej: Marvel vs. Capcom / mvsc.zip):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pathController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Ruta de la ROM (.zip)',
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan.shade700,
              ),
              onPressed: () async {
                Navigator.pop(context);
                final path = _pathController.text.trim();
                if (path.isNotEmpty) {
                  setState(() => _isLoading = true);
                  await _emulatorService.loadRom(path);
                  setState(() => _isLoading = false);
                }
              },
              child: const Text('Cargar y Jugar',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

          // 3. Barra de herramientas superior flotante
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  _emulatorService.currentRomPath != null
                      ? _emulatorService.currentRomPath!.split('/').last
                      : 'Arcade FBNeo Engine',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _showOverlay ? Icons.touch_app : Icons.touch_app_outlined,
                    color: _showOverlay ? Colors.cyanAccent : Colors.white54,
                  ),
                  tooltip: 'Mostrar/Ocultar Controles',
                  onPressed: () => setState(() => _showOverlay = !_showOverlay),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open, color: Colors.amberAccent),
                  tooltip: 'Cargar ROM',
                  onPressed: _showLoadRomDialog,
                ),
                IconButton(
                  icon: Icon(
                    _emulatorService.isPaused
                        ? Icons.play_arrow
                        : Icons.pause,
                    color: Colors.white,
                  ),
                  tooltip: _emulatorService.isPaused ? 'Reanudar' : 'Pausar',
                  onPressed: () {
                    if (_emulatorService.isPaused) {
                      _emulatorService.resume();
                    } else {
                      _emulatorService.pause();
                    }
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.orangeAccent),
                  tooltip: 'Reiniciar',
                  onPressed: () => _emulatorService.reset(),
                ),
              ],
            ),
          ),

          // 4. Indicador de Carga
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 16),
                    Text(
                      'Inicializando motor Arcade FBNeo...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
