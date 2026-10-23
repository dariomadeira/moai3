import 'dart:async';

import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/services/gamepad_manager_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/theme/moai_icons.dart';

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
      barrierLabel: 'TvGamepadConfigDialog',
      builder: (dialogContext) => const TvGamepadConfigDialog(),
    );
  }

  @override
  State<TvGamepadConfigDialog> createState() => _TvGamepadConfigDialogState();
}

class _TvGamepadConfigDialogState extends State<TvGamepadConfigDialog> {
  final GamepadManagerService _gamepadService = GamepadManagerService();
  final FocusNode _testFocus = FocusNode(debugLabel: 'gamepad_test');
  final FocusNode _closeFocus = FocusNode(
    debugLabel: 'gamepad_close',
    canRequestFocus: false,
    skipTraversal: true,
  );
  final FocusNode _refreshFocus = FocusNode(
    debugLabel: 'gamepad_refresh',
    canRequestFocus: false,
    skipTraversal: true,
  );

  // Máscara de botones activos en tiempo real
  int _activeTestMask = 0;
  String? _lastPressedLabel;
  Timer? _backHoldTimer;
  bool _backHoldFired = false;

  @override
  void initState() {
    super.initState();
    _gamepadService.refreshGamepads();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _testFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _backHoldTimer?.cancel();
    _testFocus.dispose();
    _closeFocus.dispose();
    _refreshFocus.dispose();
    _gamepadService.dispose();
    super.dispose();
  }

  void _clearTest() {
    _gamepadService.refreshGamepads();
    if (!mounted) return;
    setState(() {
      _activeTestMask = 0;
      _lastPressedLabel = null;
    });
  }

  KeyEventResult _handleGamepadKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    final isBack = key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.backspace;
    if (isBack) {
      if (event is KeyDownEvent &&
          (_backHoldTimer == null || !_backHoldTimer!.isActive)) {
        _backHoldFired = false;
        _backHoldTimer = Timer(const Duration(milliseconds: 650), () {
          _backHoldFired = true;
          _clearTest();
        });
      } else if (event is KeyUpEvent) {
        _backHoldTimer?.cancel();
        _backHoldTimer = null;
        if (!_backHoldFired && mounted) {
          Navigator.of(context).pop();
        }
        _backHoldFired = false;
      }
      return KeyEventResult.handled;
    }

    int bit = 0;
    String label = '';

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.gameButton11) {
      bit = ArcadeButtons.up;
      label = LocaleKeys.gamepad_dpad_up.tr();
    } else if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.gameButton12) {
      bit = ArcadeButtons.down;
      label = LocaleKeys.gamepad_dpad_down.tr();
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.gameButton13) {
      bit = ArcadeButtons.left;
      label = LocaleKeys.gamepad_dpad_left.tr();
    } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.gameButton14) {
      bit = ArcadeButtons.right;
      label = LocaleKeys.gamepad_dpad_right.tr();
    } else if (key == LogicalKeyboardKey.gameButtonX || key == LogicalKeyboardKey.keyY || key == LogicalKeyboardKey.keyJ) {
      bit = ArcadeButtons.punchLight;
      label = LocaleKeys.gamepad_btn_lp.tr();
    } else if (key == LogicalKeyboardKey.gameButtonY || key == LogicalKeyboardKey.keyX || key == LogicalKeyboardKey.keyI) {
      bit = ArcadeButtons.punchMedium;
      label = LocaleKeys.gamepad_btn_mp.tr();
    } else if (key == LogicalKeyboardKey.gameButtonRight1 || key == LogicalKeyboardKey.keyL || key == LogicalKeyboardKey.keyO) {
      bit = ArcadeButtons.punchHeavy;
      label = LocaleKeys.gamepad_btn_hp.tr();
    } else if (TvKeyHandler.isActionKey(key) ||
        key == LogicalKeyboardKey.keyB ||
        key == LogicalKeyboardKey.keyK) {
      bit = ArcadeButtons.kickLight;
      label = LocaleKeys.gamepad_btn_lk.tr();
    } else if (key == LogicalKeyboardKey.gameButtonB || key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.keyM) {
      bit = ArcadeButtons.kickMedium;
      label = LocaleKeys.gamepad_btn_mk.tr();
    } else if (key == LogicalKeyboardKey.gameButtonRight2 || key == LogicalKeyboardKey.keyR || key == LogicalKeyboardKey.comma) {
      bit = ArcadeButtons.kickHeavy;
      label = LocaleKeys.gamepad_btn_hk.tr();
    } else if (key == LogicalKeyboardKey.gameButtonSelect || key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.digit5) {
      bit = ArcadeButtons.coin;
      label = LocaleKeys.gamepad_btn_coin.tr();
    } else if (key == LogicalKeyboardKey.gameButtonStart || key == LogicalKeyboardKey.digit1) {
      bit = ArcadeButtons.start;
      label = LocaleKeys.gamepad_btn_start.tr();
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

    return Focus(
      focusNode: _testFocus,
      autofocus: true,
      onKeyEvent: _handleGamepadKeyEvent,
      child: AnimatedBuilder(
        animation: _gamepadService,
        builder: (context, _) {
          final isConnected = _gamepadService.hasGamepadConnected;
          final connectedList = _gamepadService.connectedGamepads;

          final baseColor = scheme.surface.withValues(alpha: 0.8);
          final endColor = Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.05),
            baseColor,
          );
          final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

          final panelDecoration = BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
              colors: [baseColor, baseColor, endColor],
              stops: const [0.0, 0.62, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
            ),
          );

          return TvDialog(
            width: 860,
            icon: MoaiIcons.symbolSportsEsports,
            title: LocaleKeys.gamepad_dialog_title.tr(),
            subtitle: LocaleKeys.gamepad_dialog_subtitle.tr(),
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
                          ? MoaiIcons.checkCircleOutlineRounded
                          : MoaiIcons.videogameAssetOffOutlined,
                      size: 15,
                      color: isConnected
                          ? scheme.onTertiaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected
                          ? (connectedList.length == 1
                              ? LocaleKeys.gamepad_count_single.tr(namedArgs: {
                                  'count': '${connectedList.length}',
                                })
                              : LocaleKeys.gamepad_count_plural.tr(namedArgs: {
                                  'count': '${connectedList.length}',
                                }))
                          : LocaleKeys.gamepad_status_not_connected.tr(),
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
                            Icon(MoaiIcons.gamepad, size: 14, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              LocaleKeys.gamepad_detected_section_header.tr(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                          decoration: panelDecoration,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  MoaiIcons.videogameAssetOff,
                                  size: 28,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                LocaleKeys.gamepad_device_none.tr(),
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
                                LocaleKeys.gamepad_device_none_hint.tr(),
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
                                decoration: panelDecoration,
                              ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      // Tarjeta informativa compacta sobre controles arcade
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(MoaiIcons.info, size: 14, color: scheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                LocaleKeys.gamepad_support_two_players.tr(),
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
                  flex: 13,
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
                                Icon(MoaiIcons.joystick, size: 14, color: scheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  LocaleKeys.gamepad_test_section.tr().toUpperCase(),
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
                              Flexible(
                                child: Text(
                                  _lastPressedLabel!,
                                  overflow: TextOverflow.ellipsis,
                                  style: MoaiText.body(
                                    context,
                                    color: scheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: panelDecoration,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fila superior: D-Pad a la izquierda + Sistema (Coin / Start) a la derecha
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // D-Pad en cruz compacto con squircles
                                SizedBox(
                                  width: 108,
                                  height: 108,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Arriba
                                      Positioned(
                                        top: 0,
                                        child: _SquircleButton(
                                          icon: MoaiIcons.arrowUpwardRounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.up) != 0,
                                          size: 34,
                                        ),
                                      ),
                                      // Izquierda
                                      Positioned(
                                        left: 0,
                                        child: _SquircleButton(
                                          icon: MoaiIcons.arrowBackRounded,
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
                                          icon: MoaiIcons.arrowForwardRounded,
                                          isPressed: (_activeTestMask & ArcadeButtons.right) != 0,
                                          size: 34,
                                        ),
                                      ),
                                      // Abajo
                                      Positioned(
                                        bottom: 0,
                                        child: _SquircleButton(
                                          icon: MoaiIcons.arrowDownwardRounded,
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
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _SquircleButton(
                                          label: 'COIN',
                                          subtitle: '5/9',
                                          isPressed: (_activeTestMask & ArcadeButtons.coin) != 0,
                                          height: 34,
                                          activeColor: const Color(0xFFFFB300),
                                        ),
                                        const SizedBox(width: 8),
                                        _SquircleButton(
                                          label: 'START',
                                          subtitle: '1',
                                          isPressed: (_activeTestMask & ArcadeButtons.start) != 0,
                                          height: 34,
                                          activeColor: const Color(0xFF43A047),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      LocaleKeys.gamepad_coin_start_header.tr(),
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
                                color: borderColor.withValues(alpha: 0.4),
                              ),
                            ),
                            // Botonera de Acción Arcade (CPS / Lucha: 6 botones)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  LocaleKeys.gamepad_attacks_cps_header.tr(),
                                  style: MoaiText.body(
                                    context,
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  LocaleKeys.gamepad_levels_weak_med_strong.tr(),
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
                              children: [
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'LP',
                                    subtitle: 'X',
                                    isPressed: (_activeTestMask & ArcadeButtons.punchLight) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFFE53935),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'MP',
                                    subtitle: 'Y',
                                    isPressed: (_activeTestMask & ArcadeButtons.punchMedium) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFFFB8C00),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'HP',
                                    subtitle: 'R1',
                                    isPressed: (_activeTestMask & ArcadeButtons.punchHeavy) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFF1E88E5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Fila 2: Patadas (LK, MK, HK)
                            Row(
                              children: [
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'LK',
                                    subtitle: 'A',
                                    isPressed: (_activeTestMask & ArcadeButtons.kickLight) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFFD81B60),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'MK',
                                    subtitle: 'B',
                                    isPressed: (_activeTestMask & ArcadeButtons.kickMedium) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFF8E24AA),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SquircleButton(
                                    label: 'HK',
                                    subtitle: 'R2',
                                    isPressed: (_activeTestMask & ArcadeButtons.kickHeavy) != 0,
                                    height: 38,
                                    activeColor: const Color(0xFF3949AB),
                                  ),
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
                icon: MoaiIcons.refreshRounded,
                label: LocaleKeys.gamepad_action_reset.tr(),
                onPressed: _clearTest,
              ),
              TvDialogButton(
                focusNode: _closeFocus,
                icon: MoaiIcons.checkRounded,
                label: LocaleKeys.gamepad_action_close.tr(),
                variant: TvDialogButtonVariant.primary,
                onPressed: () => Navigator.of(context).pop(),
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
  final double? height;
  final double? size;
  final Color? activeColor;

  const _SquircleButton({
    this.label,
    this.subtitle,
    this.icon,
    required this.isPressed,
    this.height,
    this.size,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
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
        width: size,
        height: h,
        padding: size != null ? null : const EdgeInsets.symmetric(horizontal: 10),
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
  final Decoration? decoration;

  const _GamepadDeviceCard({
    required this.index,
    required this.device,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

    final effectiveDecoration = decoration ??
        BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [baseColor, baseColor, endColor],
            stops: const [0.0, 0.62, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: effectiveDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              MoaiIcons.symbolSportsEsports,
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
                      LocaleKeys.gamepad_controller_label.tr(
                        namedArgs: {'index': '$index'},
                      ),
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
                        LocaleKeys.common_active.tr(),
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
