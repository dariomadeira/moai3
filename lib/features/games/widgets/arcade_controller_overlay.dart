import 'package:flutter/material.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';

/// Overlay visual de controles táctiles estilo Arcade (CPS-2 Capcom: 6 Botones + D-Pad + Coin/Start).
class ArcadeControllerOverlay extends StatefulWidget {
  final ArcadeEmulatorService service;
  final bool showControls;

  const ArcadeControllerOverlay({
    super.key,
    required this.service,
    this.showControls = true,
  });

  @override
  State<ArcadeControllerOverlay> createState() => _ArcadeControllerOverlayState();
}

class _ArcadeControllerOverlayState extends State<ArcadeControllerOverlay> {
  int _activeInputMask = 0;

  void _updateButtonState(int buttonBitmask, bool isPressed) {
    setState(() {
      if (isPressed) {
        _activeInputMask |= buttonBitmask;
      } else {
        _activeInputMask &= ~buttonBitmask;
      }
    });
    widget.service.sendInputMask(_activeInputMask);
  }

  Widget _buildArcadeButton({
    required String label,
    required Color color,
    required int bitmask,
    double size = 52.0,
  }) {
    final bool isPressed = (_activeInputMask & bitmask) != 0;

    return GestureDetector(
      onTapDown: (_) => _updateButtonState(bitmask, true),
      onTapUp: (_) => _updateButtonState(bitmask, false),
      onTapCancel: () => _updateButtonState(bitmask, false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPressed ? color.withAlpha(240) : color.withAlpha(160),
          border: Border.all(
            color: Colors.white.withAlpha(200),
            width: isPressed ? 3.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(isPressed ? 180 : 80),
              blurRadius: isPressed ? 12 : 4,
              spreadRadius: isPressed ? 2 : 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDPadButton(String label, int bitmask, List<List<dynamic>> icon) {
    final bool isPressed = (_activeInputMask & bitmask) != 0;

    return GestureDetector(
      onTapDown: (_) => _updateButtonState(bitmask, true),
      onTapUp: (_) => _updateButtonState(bitmask, false),
      onTapCancel: () => _updateButtonState(bitmask, false),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isPressed ? Colors.white38 : Colors.black45,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: AppIcon(
          icon: icon,
          color: isPressed ? Colors.cyanAccent : Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildDPad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDPadButton('UP', ArcadeButtons.up, AppIcons.arrowUp),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDPadButton('LEFT', ArcadeButtons.left, AppIcons.arrowLeft),
            const SizedBox(width: 44, height: 44),
            _buildDPadButton('RIGHT', ArcadeButtons.right, AppIcons.arrowRight),
          ],
        ),
        _buildDPadButton('DOWN', ArcadeButtons.down, AppIcons.arrowDown),
      ],
    );
  }

  Widget _buildCapcom6ButtonGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila Superior: Puños (LP, MP, HP)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArcadeButton(
              label: 'LP',
              color: Colors.redAccent,
              bitmask: ArcadeButtons.punchLight,
            ),
            const SizedBox(width: 12),
            _buildArcadeButton(
              label: 'MP',
              color: Colors.yellow.shade700,
              bitmask: ArcadeButtons.punchMedium,
            ),
            const SizedBox(width: 12),
            _buildArcadeButton(
              label: 'HP',
              color: Colors.blueAccent,
              bitmask: ArcadeButtons.punchHeavy,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Fila Inferior: Patadas (LK, MK, HK)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArcadeButton(
              label: 'LK',
              color: Colors.deepOrangeAccent,
              bitmask: ArcadeButtons.kickLight,
            ),
            const SizedBox(width: 12),
            _buildArcadeButton(
              label: 'MK',
              color: Colors.amber.shade800,
              bitmask: ArcadeButtons.kickMedium,
            ),
            const SizedBox(width: 12),
            _buildArcadeButton(
              label: 'HK',
              color: Colors.indigoAccent,
              bitmask: ArcadeButtons.kickHeavy,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildArcadeButton(
          label: 'COIN',
          color: Colors.amber.shade900,
          bitmask: ArcadeButtons.coin,
          size: 44,
        ),
        const SizedBox(width: 16),
        _buildArcadeButton(
          label: 'START',
          color: Colors.green.shade700,
          bitmask: ArcadeButtons.start,
          size: 44,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showControls) return const SizedBox.shrink();

    return SafeArea(
      child: Stack(
        children: [
          // D-Pad a la izquierda abajo
          Positioned(
            left: 20,
            bottom: 20,
            child: _buildDPad(),
          ),
          // Botones de acción a la derecha abajo
          Positioned(
            right: 20,
            bottom: 20,
            child: _buildCapcom6ButtonGrid(),
          ),
          // Botones COIN / START arriba al centro
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: _buildSystemButtons(),
            ),
          ),
        ],
      ),
    );
  }
}
