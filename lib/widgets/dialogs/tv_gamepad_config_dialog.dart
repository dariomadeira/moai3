import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/services/gamepad_manager_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/context_extensions.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

/// Modal interactivo para diagnosticar, probar y configurar mandos físicos (Bluetooth / USB).
class TvGamepadConfigDialog extends StatefulWidget {
  const TvGamepadConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvGamepadConfigDialog',
      builder: (dialogContext) => const TvGamepadConfigDialog(),
    );
  }

  @override
  State<TvGamepadConfigDialog> createState() => _TvGamepadConfigDialogState();
}

class _TvGamepadConfigDialogState extends State<TvGamepadConfigDialog> {
  final GamepadManagerService _gamepadService = GamepadManagerService();
  final FocusNode _closeFocus = FocusNode(debugLabel: 'gamepad_close');
  final FocusNode _refreshFocus = FocusNode(debugLabel: 'gamepad_refresh');

  // Estado del tester de botones en vivo
  int _activeTestMask = 0;
  String? _lastPressedLabel;

  @override
  void initState() {
    super.initState();
    _gamepadService.refreshGamepads();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _closeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _closeFocus.dispose();
    _refreshFocus.dispose();
    _gamepadService.dispose();
    super.dispose();
  }

  KeyEventResult _handleGamepadKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    // Permitir salir con Escape / Back
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape ||
         key == LogicalKeyboardKey.goBack ||
         key == LogicalKeyboardKey.backspace)) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    int bit = 0;
    String label = '';

    // Mapeo interactivo D-Pad y Botones Arcade
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.gameButton11) {
      bit = ArcadeButtons.up;
      label = 'D-Pad Arriba';
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.gameButton12) {
      bit = ArcadeButtons.down;
      label = 'D-Pad Abajo';
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.gameButton13) {
      bit = ArcadeButtons.left;
      label = 'D-Pad Izquierda';
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.gameButton14) {
      bit = ArcadeButtons.right;
      label = 'D-Pad Derecha';
    } else if (key == LogicalKeyboardKey.gameButtonX || key == LogicalKeyboardKey.keyY) {
      bit = ArcadeButtons.punchLight;
      label = 'LP (Low Punch)';
    } else if (key == LogicalKeyboardKey.gameButtonY || key == LogicalKeyboardKey.keyX) {
      bit = ArcadeButtons.punchMedium;
      label = 'MP (Medium Punch)';
    } else if (key == LogicalKeyboardKey.gameButtonRight1 || key == LogicalKeyboardKey.keyL) {
      bit = ArcadeButtons.punchHeavy;
      label = 'HP (Heavy Punch)';
    } else if (key == LogicalKeyboardKey.gameButtonA || key == LogicalKeyboardKey.keyB) {
      bit = ArcadeButtons.kickLight;
      label = 'LK (Low Kick)';
    } else if (key == LogicalKeyboardKey.gameButtonB || key == LogicalKeyboardKey.keyA) {
      bit = ArcadeButtons.kickMedium;
      label = 'MK (Medium Kick)';
    } else if (key == LogicalKeyboardKey.gameButtonRight2 || key == LogicalKeyboardKey.keyR) {
      bit = ArcadeButtons.kickHeavy;
      label = 'HK (Heavy Kick)';
    } else if (key == LogicalKeyboardKey.gameButtonSelect || key == LogicalKeyboardKey.digit9) {
      bit = ArcadeButtons.coin;
      label = 'COIN (Ficha)';
    } else if (key == LogicalKeyboardKey.gameButtonStart || key == LogicalKeyboardKey.digit1) {
      bit = ArcadeButtons.start;
      label = 'START';
    }

    if (bit != 0) {
      setState(() {
        if (event is KeyDownEvent) {
          _activeTestMask |= bit;
          _lastPressedLabel = label;
        } else if (event is KeyUpEvent) {
          _activeTestMask &= ~bit;
        }
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return FocusScope(
      onKeyEvent: _handleGamepadKeyEvent,
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 780,
              maxHeight: 520,
            ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context, scheme),
                const SizedBox(height: 18),

                // 2 Columnas: Estado de Dispositivos + Tester de Botones
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna 1: Dispositivo y Modos
                      Expanded(
                        flex: 5,
                        child: _buildDeviceColumn(context, scheme),
                      ),
                      const SizedBox(width: 20),
                      // Columna 2: Tester Visual Interactivo
                      Expanded(
                        flex: 6,
                        child: _buildTesterColumn(context, scheme),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Footer de Acciones
                _buildFooter(context, scheme),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _gamepadService,
      builder: (context, _) {
        final isConnected = _gamepadService.hasGamepadConnected;
        return Row(
          children: [
            Material(
              color: scheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Symbols.gamepad,
                  color: scheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'gamepad_dialog_title'.tr(),
                    style: MoaiText.display(
                      context,
                      color: scheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'gamepad_dialog_subtitle'.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Tag / Pill de Estado
            Material(
              color: isConnected
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(
                  isConnected
                      ? 'gamepad_status_connected'.tr()
                      : 'gamepad_status_not_connected'.tr(),
                  style: MoaiText.body(
                    context,
                    color: isConnected
                        ? scheme.onTertiaryContainer
                        : scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceColumn(BuildContext context, ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _gamepadService,
      builder: (context, _) {
        final gamepads = _gamepadService.connectedGamepads;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'gamepad_device_section'.tr(),
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: gamepads.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Symbols.videogame_asset_off,
                              size: 36,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'gamepad_device_none'.tr(),
                              textAlign: TextAlign.center,
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'gamepad_device_none_hint'.tr(),
                              textAlign: TextAlign.center,
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: gamepads.length,
                        itemBuilder: (context, i) {
                          final pad = gamepads[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Symbols.sports_esports,
                                    size: 22,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          pad.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: MoaiText.body(
                                            context,
                                            color: scheme.onSurface,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'ID: ${pad.id} · Bluetooth / USB',
                                          style: MoaiText.body(
                                            context,
                                            color: scheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTesterColumn(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'gamepad_test_section'.tr(),
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_lastPressedLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastPressedLabel!,
                  style: MoaiText.body(
                    context,
                    color: scheme.onPrimaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Fila Superior: D-Pad y Botones Coin / Start
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // D-Pad Mini
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniKey('↑', ArcadeButtons.up, scheme),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMiniKey('←', ArcadeButtons.left, scheme),
                            const SizedBox(width: 26, height: 26),
                            _buildMiniKey('→', ArcadeButtons.right, scheme),
                          ],
                        ),
                        _buildMiniKey('↓', ArcadeButtons.down, scheme),
                      ],
                    ),
                    // COIN / START
                    Row(
                      children: [
                        _buildPillKey('COIN', ArcadeButtons.coin, scheme),
                        const SizedBox(width: 10),
                        _buildPillKey('START', ArcadeButtons.start, scheme),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 16, thickness: 0.5),

                // Grid 6 Botones Capcom CPS-2
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Puños (LP, MP, HP)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildArcadeKey('LP', ArcadeButtons.punchLight, Colors.redAccent, scheme),
                        const SizedBox(width: 12),
                        _buildArcadeKey('MP', ArcadeButtons.punchMedium, Colors.amber.shade700, scheme),
                        const SizedBox(width: 12),
                        _buildArcadeKey('HP', ArcadeButtons.punchHeavy, Colors.blueAccent, scheme),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Patadas (LK, MK, HK)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildArcadeKey('LK', ArcadeButtons.kickLight, Colors.deepOrangeAccent, scheme),
                        const SizedBox(width: 12),
                        _buildArcadeKey('MK', ArcadeButtons.kickMedium, Colors.amber.shade800, scheme),
                        const SizedBox(width: 12),
                        _buildArcadeKey('HK', ArcadeButtons.kickHeavy, Colors.indigoAccent, scheme),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniKey(String label, int bitmask, ColorScheme scheme) {
    final isPressed = (_activeTestMask & bitmask) != 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isPressed ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPressed ? scheme.onPrimary : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isPressed ? scheme.onPrimary : scheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPillKey(String label, int bitmask, ColorScheme scheme) {
    final isPressed = (_activeTestMask & bitmask) != 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPressed ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPressed ? scheme.onPrimary : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isPressed ? scheme.onPrimary : scheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildArcadeKey(String label, int bitmask, Color color, ColorScheme scheme) {
    final isPressed = (_activeTestMask & bitmask) != 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPressed ? color : color.withValues(alpha: 0.25),
        border: Border.all(
          color: isPressed ? Colors.white : color.withValues(alpha: 0.6),
          width: isPressed ? 2.5 : 1.5,
        ),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isPressed ? Colors.white : scheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón Actualizar Detección
        _FocusButton(
          focusNode: _refreshFocus,
          label: 'gamepad_action_reset'.tr(),
          icon: Symbols.refresh,
          onPressed: () => _gamepadService.refreshGamepads(),
          onFocusRight: () => _closeFocus.requestFocus(),
        ),

        // Botón Listo / Cerrar
        _FocusButton(
          focusNode: _closeFocus,
          label: 'gamepad_action_close'.tr(),
          icon: Symbols.check,
          isPrimary: true,
          onPressed: () => Navigator.of(context).pop(),
          onFocusLeft: () => _refreshFocus.requestFocus(),
        ),
      ],
    );
  }
}

class _FocusButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;

  const _FocusButton({
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.onFocusLeft,
    this.onFocusRight,
  });

  @override
  State<_FocusButton> createState() => _FocusButtonState();
}

class _FocusButtonState extends State<_FocusButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused
        ? (widget.isPrimary ? scheme.primary : scheme.surfaceContainerHighest)
        : (widget.isPrimary ? scheme.primaryContainer : scheme.surfaceContainerLow);
    final fg = _isFocused
        ? (widget.isPrimary ? scheme.onPrimary : scheme.onSurface)
        : (widget.isPrimary ? scheme.onPrimaryContainer : scheme.onSurfaceVariant);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft && widget.onFocusLeft != null) {
          widget.onFocusLeft!();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && widget.onFocusRight != null) {
          widget.onFocusRight!();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: MoaiText.body(
                      context,
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
