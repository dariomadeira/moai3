import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

/// Diálogo modal TV para entrada y configuración de PIN de 4 dígitos.
///
/// Totalmente accesible con control remoto (D-Pad) y teclas numéricas directas.
class TvPinDialog extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Future<bool> Function(String pin)? onValidate;

  const TvPinDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.onValidate,
  });

  /// Muestra el diálogo para ingresar y validar un PIN existente o capturar 4 dígitos.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Future<bool> Function(String pin)? onValidate,
  }) {
    return showGeneralDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        title: title,
        subtitle: subtitle,
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
      // Si aún no tiene PIN, guiamos a crear uno
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

    final result = await show(
      context,
      title: 'parental_pin_title_enter'.tr(),
      subtitle: 'settings_tv_adult_content_desc'.tr(),
      onValidate: (pin) async {
        return tvSettings.verifyPin(pin);
      },
    );

    if (result != null && context.mounted) {
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

  /// Flujo guiado para crear un nuevo PIN (Paso 1: Crear, Paso 2: Confirmar).
  static Future<bool> setupNewPin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    final pin1 = await show(
      context,
      title: 'parental_pin_title_create'.tr(),
      subtitle: 'parental_pin_create_subtitle'.tr(),
    );

    if (pin1 == null || pin1.length != 4 || !context.mounted) return false;

    final pin2 = await show(
      context,
      title: 'parental_pin_title_confirm'.tr(),
      subtitle: 'parental_pin_confirm_subtitle'.tr(),
    );

    if (pin2 == null || !context.mounted) return false;

    if (pin1 != pin2) {
      MoaiSnackBar.show(
        context,
        message: 'parental_pin_error_mismatch'.tr(),
        icon: Icons.error_outline,
      );
      return false;
    }

    await tvSettings.setParentalPin(pin1);
    if (context.mounted) {
      MoaiSnackBar.show(
        context,
        message: 'parental_pin_created_success'.tr(),
        icon: Icons.check_circle_outline,
      );
    }
    return true;
  }

  /// Flujo para cambiar el PIN existente (Paso 0: Actual, Paso 1: Nuevo, Paso 2: Confirmar).
  static Future<bool> changePin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    if (tvSettings.hasParentalPin) {
      final currentOk = await show(
        context,
        title: 'parental_pin_title_current'.tr(),
        subtitle: 'parental_pin_current_subtitle'.tr(),
        onValidate: (pin) async => tvSettings.verifyPin(pin),
      );
      if (currentOk == null || !context.mounted) return false;
    }

    final changed = await setupNewPin(context, tvSettings);
    if (changed && context.mounted) {
      MoaiSnackBar.show(
        context,
        message: 'parental_pin_changed_success'.tr(),
        icon: Icons.check_circle_outline,
      );
    }
    return changed;
  }

  @override
  State<TvPinDialog> createState() => _TvPinDialogState();
}

class _TvPinDialogState extends State<TvPinDialog> {
  String _digits = '';
  String? _errorMessage;
  bool _validating = false;

  // FocusNodes para el teclado virtual: 1-9 (0..8), ⌫ (9), 0 (10), Cancelar (11)
  final List<FocusNode> _keypadFocusNodes = List.generate(
    12,
    (i) => FocusNode(debugLabel: 'pin_key_$i'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Enfocar el botón 1 o el centro
        _keypadFocusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final node in _keypadFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(String digit) {
    if (_validating || _digits.length >= 4) return;
    setState(() {
      _errorMessage = null;
      _digits += digit;
    });

    if (_digits.length == 4) {
      _processPin();
    }
  }

  void _onBackspace() {
    if (_validating || _digits.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  Future<void> _processPin() async {
    if (_digits.length != 4) return;

    if (widget.onValidate != null) {
      setState(() => _validating = true);
      final isValid = await widget.onValidate!(_digits);
      if (!mounted) return;
      setState(() => _validating = false);

      if (isValid) {
        Navigator.of(context).pop(_digits);
      } else {
        setState(() {
          _digits = '';
          _errorMessage = 'parental_pin_error_incorrect'.tr();
        });
      }
    } else {
      Navigator.of(context).pop(_digits);
    }
  }

  KeyEventResult _handleGlobalKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Números directos del control remoto o teclado
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

    return Focus(
      onKeyEvent: _handleGlobalKeyEvent,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Symbols.lock,
                    color: scheme.onPrimaryContainer,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),

                // Título
                Text(
                  widget.title,
                  style: MoaiText.display(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (widget.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle!,
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 20),

                // 4 Cajas/Dígitos de PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _digits.length;
                    final isCurrent = index == _digits.length;

                    return Container(
                      width: 44,
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? scheme.primary.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? scheme.primary
                              : (isFilled
                                  ? scheme.primary.withValues(alpha: 0.6)
                                  : scheme.outline.withValues(alpha: 0.3)),
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isFilled
                          ? Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : (isCurrent
                              ? Container(
                                  width: 4,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                )
                              : null),
                    );
                  }),
                ),

                // Mensaje de error
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  const SizedBox(height: 16),

                // Teclado numérico virtual 3x4
                _buildKeypad(scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 1: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyBtn(index: 0, label: '1', scheme: scheme, onTap: () => _onDigitEntered('1')),
            _buildKeyBtn(index: 1, label: '2', scheme: scheme, onTap: () => _onDigitEntered('2')),
            _buildKeyBtn(index: 2, label: '3', scheme: scheme, onTap: () => _onDigitEntered('3')),
          ],
        ),
        const SizedBox(height: 8),
        // Fila 2: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyBtn(index: 3, label: '4', scheme: scheme, onTap: () => _onDigitEntered('4')),
            _buildKeyBtn(index: 4, label: '5', scheme: scheme, onTap: () => _onDigitEntered('5')),
            _buildKeyBtn(index: 5, label: '6', scheme: scheme, onTap: () => _onDigitEntered('6')),
          ],
        ),
        const SizedBox(height: 8),
        // Fila 3: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyBtn(index: 6, label: '7', scheme: scheme, onTap: () => _onDigitEntered('7')),
            _buildKeyBtn(index: 7, label: '8', scheme: scheme, onTap: () => _onDigitEntered('8')),
            _buildKeyBtn(index: 8, label: '9', scheme: scheme, onTap: () => _onDigitEntered('9')),
          ],
        ),
        const SizedBox(height: 8),
        // Fila 4: ⌫, 0, Cancelar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeyBtn(
              index: 9,
              icon: Icons.backspace_outlined,
              scheme: scheme,
              onTap: _onBackspace,
            ),
            _buildKeyBtn(index: 10, label: '0', scheme: scheme, onTap: () => _onDigitEntered('0')),
            _buildKeyBtn(
              index: 11,
              icon: Icons.close,
              scheme: scheme,
              onTap: () => Navigator.of(context).pop(null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyBtn({
    required int index,
    String? label,
    IconData? icon,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    final focusNode = _keypadFocusNodes[index];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;

            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 74,
                height: 44,
                decoration: BoxDecoration(
                  color: isFocused
                      ? scheme.primary
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused
                        ? scheme.onPrimary
                        : scheme.outlineVariant.withValues(alpha: 0.25),
                    width: isFocused ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: label != null
                    ? Text(
                        label,
                        style: MoaiText.display(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isFocused ? scheme.onPrimary : scheme.onSurface,
                        ),
                      )
                    : Icon(
                        icon,
                        color: isFocused ? scheme.onPrimary : scheme.onSurface,
                        size: 20,
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
