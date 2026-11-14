part of '../tv_pin_dialog.dart';

/// Teclas de número de un teclado físico, en orden: la posición es el dígito.
const _pinRowKeys = [
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];
const _pinNumpadKeys = [
  LogicalKeyboardKey.numpad0,
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// El dígito de [key] ("0" a "9"), o null si no es una tecla de número.
String? _pinDigitOf(LogicalKeyboardKey key) {
  var index = _pinRowKeys.indexOf(key);
  if (index < 0) index = _pinNumpadKeys.indexOf(key);
  return index < 0 ? null : '$index';
}

/// Ingreso de dígitos, validación por pasos y navegación D-pad del teclado.
extension _TvPinDialogInput on _TvPinDialogState {
  void _triggerError(String message) {
    _update(() {
      _errorMessage = message;
      _digits = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _onDigitEntered(String digit) {
    if (_validating || _digits.length >= 4) return;

    _update(() {
      _errorMessage = null;
      _digits += digit;
    });

    if (_digits.length == 4) {
      _processCompletedPin();
    }
  }

  void _onBackspace() {
    if (_validating || _digits.isEmpty) return;
    _update(() {
      _errorMessage = null;
      _digits = _digits.substring(0, _digits.length - 1);
    });
  }

  Future<void> _processCompletedPin() async {
    final entered = _digits;

    switch (widget.mode) {
      case TvPinDialogMode.verify:
        if (widget.onValidate != null) {
          _update(() => _validating = true);
          final ok = await widget.onValidate!(entered);
          if (!mounted) return;
          _update(() => _validating = false);

          if (ok) {
            Navigator.of(context).pop(entered);
          } else {
            _triggerError(LocaleKeys.parental_pin_error_incorrect.tr());
          }
        } else if (widget.tvSettings != null) {
          final ok = widget.tvSettings!.verifyPin(entered);
          if (ok) {
            Navigator.of(context).pop(true);
          } else {
            _triggerError(LocaleKeys.parental_pin_error_incorrect.tr());
          }
        } else {
          Navigator.of(context).pop(entered);
        }
        break;

      case TvPinDialogMode.create:
        if (_currentStep == 1) {
          _update(() {
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
            _triggerError(LocaleKeys.parental_pin_error_mismatch.tr());
            _update(() {
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
            _update(() {
              _currentStep = 2;
              _digits = '';
              _errorMessage = null;
            });
          } else {
            _triggerError(LocaleKeys.parental_pin_error_incorrect.tr());
          }
        } else if (_currentStep == 2) {
          _update(() {
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
            _triggerError(LocaleKeys.parental_pin_error_mismatch.tr());
            _update(() {
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
    final digit = _pinDigitOf(key);
    if (digit != null) {
      _onDigitEntered(digit);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
