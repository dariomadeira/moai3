import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

/// Curva sinusoidal para sacudida suave (shake) ante errores de validación de PIN.
class _PinShakeCurve extends Curve {
  const _PinShakeCurve();

  @override
  double transformInternal(double t) {
    return sin(t * pi * 4);
  }
}

/// Modo de operación del diálogo de PIN.
enum TvPinDialogMode {
  /// Ingreso y verificación simple de PIN (ej. desbloquear sesión).
  verify,

  /// Configuración de nuevo PIN (Paso 1: Crear -> Paso 2: Confirmar).
  create,

  /// Cambio de PIN (Paso 1: Actual -> Paso 2: Nuevo -> Paso 3: Confirmar).
  change,
}

/// Diálogo modal TV para entrada, validación y configuración fluida de PIN parental (4 dígitos).
///
/// Implementa una máquina de estados interna para flujos multi-paso sin recargar ni
/// cerrar el diálogo entre pasos, evitando pantallazos.
/// Diseñado con estética M3 Expressive alineada al teclado en pantalla de la app.
class TvPinDialog extends StatefulWidget {
  final TvPinDialogMode mode;
  final String? customTitle;
  final String? customSubtitle;
  final TvSettingsProvider? tvSettings;
  final Future<bool> Function(String pin)? onValidate;

  const TvPinDialog({
    super.key,
    this.mode = TvPinDialogMode.verify,
    this.customTitle,
    this.customSubtitle,
    this.tvSettings,
    this.onValidate,
  });

  /// Muestra el diálogo en modo verificación simple o captura de 4 dígitos.
  static Future<String?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    Future<bool> Function(String pin)? onValidate,
  }) {
    return showGeneralDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.verify,
        customTitle: title,
        customSubtitle: subtitle,
        onValidate: onValidate,
      ),
    );
  }

  /// Flujo para desbloquear contenido adulto en la sesión actual.
  static Future<bool> unlockAdultSession(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    if (!tvSettings.hasParentalPin) {
      final created = await setupNewPin(context, tvSettings);
      if (created) {
        tvSettings.unlockAdultForSession();
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: 'parental_adult_unlocked'.tr(),
            icon: Symbols.lock_open,
          );
        }
        return true;
      }
      return false;
    }

    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.verify,
        tvSettings: tvSettings,
        customTitle: 'parental_pin_title_enter'.tr(),
        customSubtitle: 'settings_tv_adult_content_desc'.tr(),
      ),
    );

    if (success == true && context.mounted) {
      tvSettings.unlockAdultForSession();
      MoaiSnackBar.show(
        context,
        message: 'parental_adult_unlocked'.tr(),
        icon: Symbols.lock_open,
      );
      return true;
    }
    return false;
  }

  /// Flujo integrado para crear un nuevo PIN (Paso 1: Crear, Paso 2: Confirmar en el mismo modal).
  static Future<bool> setupNewPin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.create,
        tvSettings: tvSettings,
      ),
    );

    if (success == true && context.mounted) {
      MoaiSnackBar.show(
        context,
        message: 'parental_pin_created_success'.tr(),
        icon: Icons.check_circle_outline,
      );
      return true;
    }
    return false;
  }

  /// Flujo integrado para cambiar el PIN existente (Paso 1: Actual, Paso 2: Nuevo, Paso 3: Confirmar).
  static Future<bool> changePin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    if (!tvSettings.hasParentalPin) {
      return setupNewPin(context, tvSettings);
    }

    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.change,
        tvSettings: tvSettings,
      ),
    );

    if (success == true && context.mounted) {
      MoaiSnackBar.show(
        context,
        message: 'parental_pin_changed_success'.tr(),
        icon: Icons.check_circle_outline,
      );
      return true;
    }
    return false;
  }

  @override
  State<TvPinDialog> createState() => _TvPinDialogState();
}

class _TvPinDialogState extends State<TvPinDialog>
    with SingleTickerProviderStateMixin {
  String _digits = '';
  String? _errorMessage;
  bool _validating = false;

  // Control de pasos internos
  int _currentStep = 1;
  String _stagedPin = '';

  // Animación de sacudida (shake)
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Matriz de FocusNodes 4 filas x 3 columnas para navegación D-Pad 100% determinística
  late final List<List<FocusNode>> _focusGrid;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: const _PinShakeCurve(),
      ),
    );

    _focusGrid = List.generate(
      4,
      (r) => List.generate(
        3,
        (c) => FocusNode(debugLabel: 'pin_key_${r}_$c'),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Enfocar la tecla "1" (0, 0)
        _focusGrid[0][0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (final row in _focusGrid) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  int get _totalSteps {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return 1;
      case TvPinDialogMode.create:
        return 2;
      case TvPinDialogMode.change:
        return 3;
    }
  }

  String get _currentTitle {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return widget.customTitle ?? 'parental_pin_title_enter'.tr();
      case TvPinDialogMode.create:
        return _currentStep == 1
            ? 'parental_pin_title_create'.tr()
            : 'parental_pin_title_confirm'.tr();
      case TvPinDialogMode.change:
        if (_currentStep == 1) return 'parental_pin_title_current'.tr();
        if (_currentStep == 2) return 'parental_pin_title_create'.tr();
        return 'parental_pin_title_confirm'.tr();
    }
  }

  String get _currentSubtitle {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return widget.customSubtitle ?? 'parental_pin_create_subtitle'.tr();
      case TvPinDialogMode.create:
        return _currentStep == 1
            ? 'parental_pin_create_subtitle'.tr()
            : 'parental_pin_confirm_subtitle'.tr();
      case TvPinDialogMode.change:
        if (_currentStep == 1) return 'parental_pin_current_subtitle'.tr();
        if (_currentStep == 2) return 'parental_pin_create_subtitle'.tr();
        return 'parental_pin_confirm_subtitle'.tr();
    }
  }

  void _triggerError(String message) {
    setState(() {
      _errorMessage = message;
      _digits = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _onDigitEntered(String digit) {
    if (_validating || _digits.length >= 4) return;

    setState(() {
      _errorMessage = null;
      _digits += digit;
    });

    if (_digits.length == 4) {
      _processCompletedPin();
    }
  }

  void _onBackspace() {
    if (_validating || _digits.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  Future<void> _processCompletedPin() async {
    final entered = _digits;

    switch (widget.mode) {
      case TvPinDialogMode.verify:
        if (widget.onValidate != null) {
          setState(() => _validating = true);
          final ok = await widget.onValidate!(entered);
          if (!mounted) return;
          setState(() => _validating = false);

          if (ok) {
            Navigator.of(context).pop(entered);
          } else {
            _triggerError('parental_pin_error_incorrect'.tr());
          }
        } else if (widget.tvSettings != null) {
          final ok = widget.tvSettings!.verifyPin(entered);
          if (ok) {
            Navigator.of(context).pop(true);
          } else {
            _triggerError('parental_pin_error_incorrect'.tr());
          }
        } else {
          Navigator.of(context).pop(entered);
        }
        break;

      case TvPinDialogMode.create:
        if (_currentStep == 1) {
          setState(() {
            _stagedPin = entered;
            _currentStep = 2;
            _digits = '';
            _errorMessage = null;
          });
        } else {
          if (entered == _stagedPin) {
            if (widget.tvSettings != null) {
              await widget.tvSettings!.setParentalPin(entered);
            }
            if (mounted) Navigator.of(context).pop(true);
          } else {
            _triggerError('parental_pin_error_mismatch'.tr());
            setState(() {
              _currentStep = 1;
              _stagedPin = '';
            });
          }
        }
        break;

      case TvPinDialogMode.change:
        if (_currentStep == 1) {
          final ok = widget.tvSettings?.verifyPin(entered) ?? false;
          if (ok) {
            setState(() {
              _currentStep = 2;
              _digits = '';
              _errorMessage = null;
            });
          } else {
            _triggerError('parental_pin_error_incorrect'.tr());
          }
        } else if (_currentStep == 2) {
          setState(() {
            _stagedPin = entered;
            _currentStep = 3;
            _digits = '';
            _errorMessage = null;
          });
        } else {
          if (entered == _stagedPin) {
            if (widget.tvSettings != null) {
              await widget.tvSettings!.setParentalPin(entered);
            }
            if (mounted) Navigator.of(context).pop(true);
          } else {
            _triggerError('parental_pin_error_mismatch'.tr());
            setState(() {
              _currentStep = 2;
              _stagedPin = '';
            });
          }
        }
        break;
    }
  }

  void _moveFocus(int r, int c, int dR, int dC) {
    final nextR = (r + dR).clamp(0, 3);
    final nextC = (c + dC).clamp(0, 2);
    _focusGrid[nextR][nextC].requestFocus();
  }

  KeyEventResult _handleGlobalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Números directos físicos
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _onDigitEntered('0');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _onDigitEntered('1');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _onDigitEntered('2');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _onDigitEntered('3');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _onDigitEntered('4');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _onDigitEntered('5');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _onDigitEntered('6');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _onDigitEntered('7');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _onDigitEntered('8');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _onDigitEntered('9');
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop(null);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final stepBadge = _totalSteps > 1
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'parental_pin_step'.tr(args: ['$_currentStep', '$_totalSteps']),
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
            ),
          )
        : null;

    return Focus(
      onKeyEvent: _handleGlobalKeyEvent,
      child: TvDialog(
        width: 440,
        icon: Symbols.lock,
        titleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _currentTitle,
            key: ValueKey('title_$_currentStep'),
            style: MoaiText.display(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        subtitleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _currentSubtitle,
            key: ValueKey('sub_$_currentStep'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        trailingHeader: stepBadge != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey('badge_$_currentStep'),
                  child: stepBadge,
                ),
              )
            : null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),

            // Cajas/dígitos de PIN con animación de sacudida
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: _buildPinBoxes(scheme),
            ),

            // Espacio reservado para mensajes de error (evita saltos verticales de layout)
            Container(
              height: 24,
              alignment: Alignment.center,
              child: _errorMessage != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 13,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),

            const SizedBox(height: 2),

            // Teclado numérico virtual 3x4 integrado con navegación D-Pad
            _buildKeypad(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildPinBoxes(ColorScheme scheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _digits.length;
        final isCurrent = index == _digits.length;

        final Color bg;
        if (isFilled) {
          bg = scheme.primaryContainer;
        } else if (isCurrent) {
          bg = scheme.surfaceContainerHighest;
        } else {
          bg = scheme.surfaceContainerHigh;
        }

        return Container(
          width: 46,
          height: 50,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: isFilled ? 1.0 : (isCurrent ? 1.0 : 0.6),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            child: isFilled
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : (isCurrent
                    ? Container(
                        width: 3.5,
                        height: 18,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )
                    : Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      )),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 0: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(0, 0, label: '1', scheme: scheme, onTap: () => _onDigitEntered('1')),
            _buildKey(0, 1, label: '2', scheme: scheme, onTap: () => _onDigitEntered('2')),
            _buildKey(0, 2, label: '3', scheme: scheme, onTap: () => _onDigitEntered('3')),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 1: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(1, 0, label: '4', scheme: scheme, onTap: () => _onDigitEntered('4')),
            _buildKey(1, 1, label: '5', scheme: scheme, onTap: () => _onDigitEntered('5')),
            _buildKey(1, 2, label: '6', scheme: scheme, onTap: () => _onDigitEntered('6')),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 2: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(2, 0, label: '7', scheme: scheme, onTap: () => _onDigitEntered('7')),
            _buildKey(2, 1, label: '8', scheme: scheme, onTap: () => _onDigitEntered('8')),
            _buildKey(2, 2, label: '9', scheme: scheme, onTap: () => _onDigitEntered('9')),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 3: ⌫ (Borrar), 0, ✕ (Cancelar)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(
              3,
              0,
              icon: Icons.backspace_outlined,
              isAction: true,
              scheme: scheme,
              onTap: _onBackspace,
            ),
            _buildKey(3, 1, label: '0', scheme: scheme, onTap: () => _onDigitEntered('0')),
            _buildKey(
              3,
              2,
              icon: Icons.close_outlined,
              isAction: true,
              scheme: scheme,
              onTap: () => Navigator.of(context).pop(null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(
    int r,
    int c, {
    String? label,
    IconData? icon,
    bool isAction = false,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    final focusNode = _focusGrid[r][c];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowLeft) {
            _moveFocus(r, c, 0, -1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _moveFocus(r, c, 0, 1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            _moveFocus(r, c, -1, 0);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            _moveFocus(r, c, 1, 0);
            return KeyEventResult.handled;
          }

          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            onTap();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;

            final Color bg;
            final Color fg;

            if (isFocused) {
              bg = scheme.primary;
              fg = scheme.onPrimary;
            } else if (isAction) {
              bg = scheme.surfaceContainerHigh;
              fg = scheme.onSurfaceVariant;
            } else {
              bg = scheme.surfaceContainerHighest;
              fg = scheme.onSurface;
            }

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 72,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: label != null
                      ? Text(
                          label,
                          style: MoaiText.display(
                            context,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        )
                      : Icon(
                          icon,
                          color: fg,
                          size: 19,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
