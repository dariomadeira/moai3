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

part 'tv_gamepad/gamepad_config_columns.dart';
part 'tv_gamepad/squircle_button.dart';
part 'tv_gamepad/gamepad_device_card.dart';

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
            icon: MoaiIcons.gamepad,
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
                          ? MoaiIcons.checkCircle
                          : MoaiIcons.gamepad,
                      size: MoaiIconSizes.sm,
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
                _buildDevicesColumn(
                  context,
                  scheme,
                  panelDecoration,
                  borderColor,
                  isConnected,
                  connectedList,
                ),
                const SizedBox(width: 20),
                _buildButtonBoard(context, scheme, panelDecoration, borderColor),
              ],
            ),
            actions: [
              TvDialogButton(
                focusNode: _refreshFocus,
                icon: MoaiIcons.refresh,
                label: LocaleKeys.gamepad_action_reset.tr(),
                onPressed: _clearTest,
              ),
              TvDialogButton(
                focusNode: _closeFocus,
                icon: MoaiIcons.check,
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
