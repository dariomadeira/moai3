import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/services/gamepad_manager_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

/// Modal interactivo para diagnosticar, probar y listar mandos físicos (Bluetooth / USB).
/// Diseñado con estética Material 3 Expressive para Android TV:
/// - Columna izquierda: Lista de mandos detectados y estado.
/// - Columna derecha: Tablero visual de botones (D-Pad + Coin/Start + 6 botones Arcade)
///   en iconos cuadrados redondeados (squircles) con iluminación en tiempo real sin scroll.
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

  // Máscara de botones activos en tiempo real
  int _activeTestMask = 0;
  String? _lastPressedLabel;

  @override
  void initState() {
    super.initState();
    _gamepadService.refreshGamepads();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _closeFocus.requestFocus();
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

    // Salir con Escape / Back
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack ||
            key == LogicalKeyboardKey.backspace)) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    int bit = 0;
    String label = '';
    bool isDirectionalKey = false;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.gameButton11) {
      bit = ArcadeButtons.up;
      label = 'D-Pad Arriba';
      isDirectionalKey = (key == LogicalKeyboardKey.arrowUp);
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.gameButton12) {
      bit = ArcadeButtons.down;
      label = 'D-Pad Abajo';
      isDirectionalKey = (key == LogicalKeyboardKey.arrowDown);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.gameButton13) {
      bit = ArcadeButtons.left;
      label = 'D-Pad Izquierda';
      isDirectionalKey = (key == LogicalKeyboardKey.arrowLeft);
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.gameButton14) {
      bit = ArcadeButtons.right;
      label = 'D-Pad Derecha';
      isDirectionalKey = (key == LogicalKeyboardKey.arrowRight);
    } else if (key == LogicalKeyboardKey.gameButtonX || key == LogicalKeyboardKey.keyY || key == LogicalKeyboardKey.keyJ) {
      bit = ArcadeButtons.punchLight;
      label = 'Golpe Débil (LP)';
    } else if (key == LogicalKeyboardKey.gameButtonY || key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyI) {
      bit = ArcadeButtons.punchMedium;
      label = 'Golpe Medio (MP)';
    } else if (key == LogicalKeyboardKey.gameButtonRight1 || key == LogicalKeyboardKey.keyL || key == LogicalKeyboardKey.keyO) {
      bit = ArcadeButtons.punchHeavy;
      label = 'Golpe Fuerte (HP)';
    } else if (key == LogicalKeyboardKey.gameButtonA || key == LogicalKeyboardKey.keyB || key == LogicalKeyboardKey.keyK) {
      bit = ArcadeButtons.kickLight;
      label = 'Patada Débil (LK)';
    } else if (key == LogicalKeyboardKey.gameButtonB || key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.keyM) {
      bit = ArcadeButtons.kickMedium;
      label = 'Patada Media (MK)';
    } else if (key == LogicalKeyboardKey.gameButtonRight2 || key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.comma) {
      bit = ArcadeButtons.kickHeavy;
      label = 'Patada Fuerte (HK)';
    } else if (key == LogicalKeyboardKey.gameButtonSelect || key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.digit5) {
      bit = ArcadeButtons.coin;
      label = 'Ficha (COIN)';
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
      // Dejar fluir flechas de teclado para no bloquear navegación de foco D-Pad
      if (isDirectionalKey) {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return FocusScope(
      onKeyEvent: _handleGamepadKeyEvent,
      child: AnimatedBuilder(
        animation: _gamepadService,
        builder: (context, _) {
          final isConnected = _gamepadService.hasGamepadConnected;
          final connectedList = _gamepadService.connectedGamepads;

          return TvDialog(
            width: 820,
            icon: Symbols.sports_esports,
            title: 'gamepad_dialog_title'.tr(),
            subtitle: 'gamepad_dialog_subtitle'.tr(),
            trailingHeader: Material(
              color: isConnected
                  ? scheme.tertiaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected
                          ? Icons.check_circle_outline_rounded
                          : Icons.videogame_asset_off_outlined,
                      size: 15,
                      color: isConnected
                          ? scheme.onTertiaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected
                          ? '${connectedList.length} ${connectedList.length == 1 ? "mando detectado" : "mandos detectados"}'
                          : 'gamepad_status_not_connected'.tr(),
                      style: MoaiText.body(
                        context,
                        color: isConnected
                            ? scheme.onTertiaryContainer
                            : scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            content: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna 1: Lista de mandos detectados
                Expanded(
                  flex: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(
                          children: [
                            Icon(Symbols.gamepad, size: 14, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'MANDOS DETECTADOS',
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: scheme.outlineVariant.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Symbols.videogame_asset_off,
                                  size: 28,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'gamepad_device_none'.tr(),
                                textAlign: TextAlign.center,
                                style: MoaiText.body(
                                  context,
                                  color: scheme.onSurface,
                                  fontSize: 12.5,
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
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < connectedList.length; i++)
                              _GamepadDeviceCard(
                                index: i + 1,
                                device: connectedList[i],
                              ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      // Tarjeta informativa compacta sobre controles arcade
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Symbols.info, size: 14, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Soporta hasta 2 controles simultáneos (Jugador 1 y Jugador 2) para arcade.',
                                style: MoaiText.body(
                                  context,
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Columna 2: Tablero visual de botones en tiempo real (Squircles M3)
                Expanded(
                  flex: 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Symbols.joystick, size: 14, color: scheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'PRUEBA DE BOTONES',
                                  style: MoaiText.body(
                                    context,
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            if (_lastPressedLabel != null)
                              Text(
                                _lastPressedLabel!,
                                style: MoaiText.body(
                                  context,
                                  color: scheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fila superior: D-Pad a la izquierda + Sistema (Coin / Start) a la derecha
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // D-Pad en cruz compacto con squircles
                                SizedBox(
                                  width: 106,
                                  height: 106,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Arriba
                                      Positioned(
                                        top: 0,
                                        child: _SquircleButton(
                                          icon: Icons.arrow_upward_rounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.up) != 0,
                                          size: 34,
                                        ),
                                      ),
                                      // Izquierda
                                      Positioned(
                                        left: 0,
                                        child: _SquircleButton(
                                          icon: Icons.arrow_back_rounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.left) != 0,
                                          size: 34,
                                        ),
                                      ),
                                      // Centro de decoración
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      // Derecha
                                      Positioned(
                                        right: 0,
                                        child: _SquircleButton(
                                          icon: Icons.arrow_forward_rounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.right) != 0,
                                          size: 34,
                                        ),
                                      ),
                                      // Abajo
                                      Positioned(
                                        bottom: 0,
                                        child: _SquircleButton(
                                          icon: Icons.arrow_downward_rounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.down) != 0,
                                          size: 34,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Botones de Sistema: COIN y START
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        _SquircleButton(
                                          label: 'COIN',
                                          isPressed: (_activeTestMask & ArcadeButtons.coin) != 0,
                                          width: 58,
                                          height: 34,
                                          activeColor: const Color(0xFFFFB300),
                                        ),
                                        const SizedBox(width: 8),
                                        _SquircleButton(
                                          label: 'START',
                                          isPressed: (_activeTestMask & ArcadeButtons.start) != 0,
                                          width: 58,
                                          height: 34,
                                          activeColor: const Color(0xFF43A047),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ficha / Iniciar',
                                      style: MoaiText.body(
                                        context,
                                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: scheme.outlineVariant.withValues(alpha: 0.15),
                              ),
                            ),
                            // Botonera de Acción Arcade (CPS / Lucha: 6 botones)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Golpes / Patadas (CPS)',
                                  style: MoaiText.body(
                                    context,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Débil · Medio · Fuerte',
                                  style: MoaiText.body(
                                    context,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Fila 1: Golpes (LP, MP, HP)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _SquircleButton(
                                  label: 'LP',
                                  subtitle: 'X',
                                  isPressed: (_activeTestMask & ArcadeButtons.punchLight) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFFE53935),
                                ),
                                _SquircleButton(
                                  label: 'MP',
                                  subtitle: 'Y',
                                  isPressed: (_activeTestMask & ArcadeButtons.punchMedium) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFFFB8C00),
                                ),
                                _SquircleButton(
                                  label: 'HP',
                                  subtitle: 'R1',
                                  isPressed: (_activeTestMask & ArcadeButtons.punchHeavy) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFF1E88E5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Fila 2: Patadas (LK, MK, HK)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _SquircleButton(
                                  label: 'LK',
                                  subtitle: 'A',
                                  isPressed: (_activeTestMask & ArcadeButtons.kickLight) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFFD81B60),
                                ),
                                _SquircleButton(
                                  label: 'MK',
                                  subtitle: 'B',
                                  isPressed: (_activeTestMask & ArcadeButtons.kickMedium) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFF8E24AA),
                                ),
                                _SquircleButton(
                                  label: 'HK',
                                  subtitle: 'R2',
                                  isPressed: (_activeTestMask & ArcadeButtons.kickHeavy) != 0,
                                  width: 64,
                                  height: 38,
                                  activeColor: const Color(0xFF3949AB),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TvDialogButton(
                focusNode: _refreshFocus,
                icon: Icons.refresh_rounded,
                label: 'gamepad_action_reset'.tr(),
                variant: TvDialogButtonVariant.neutral,
                onPressed: () {
                  _gamepadService.refreshGamepads();
                  setState(() {
                    _activeTestMask = 0;
                    _lastPressedLabel = null;
                  });
                },
                onKeyRight: () => _closeFocus.requestFocus(),
              ),
              TvDialogButton(
                focusNode: _closeFocus,
                icon: Icons.check_rounded,
                label: 'gamepad_action_close'.tr(),
                variant: TvDialogButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
                onKeyLeft: () => _refreshFocus.requestFocus(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Botón en squircle con animación de escala, iluminación reactiva y glow en tiempo real
class _SquircleButton extends StatelessWidget {
  final String? label;
  final String? subtitle;
  final IconData? icon;
  final bool isPressed;
  final double? width;
  final double? height;
  final double? size;
  final Color? activeColor;

  const _SquircleButton({
    this.label,
    this.subtitle,
    this.icon,
    required this.isPressed,
    this.width,
    this.height,
    this.size,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final w = size ?? width ?? 40.0;
    final h = size ?? height ?? 40.0;

    final effectiveActiveColor = activeColor ?? scheme.primary;

    final bg = isPressed
        ? effectiveActiveColor
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);

    final fg = isPressed
        ? Colors.white
        : scheme.onSurface;

    return AnimatedScale(
      scale: isPressed ? 0.90 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPressed
                ? effectiveActiveColor.withValues(alpha: 0.9)
                : scheme.outlineVariant.withValues(alpha: 0.35),
            width: isPressed ? 1.5 : 1.0,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: effectiveActiveColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                size: (size != null ? size! * 0.52 : 18.0),
                color: fg,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label ?? '',
                    style: MoaiText.body(
                      context,
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      '·$subtitle',
                      style: MoaiText.body(
                        context,
                        color: isPressed
                            ? Colors.white.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Tarjeta que representa un gamepad físico conectado
class _GamepadDeviceCard extends StatelessWidget {
  final int index;
  final GamepadDeviceInfo device;

  const _GamepadDeviceCard({
    required this.index,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Symbols.sports_esports,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Mando $index',
                      style: MoaiText.body(
                        context,
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Activo',
                        style: MoaiText.body(
                          context,
                          color: scheme.onTertiaryContainer,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
