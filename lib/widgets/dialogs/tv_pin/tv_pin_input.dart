part of '../tv_pin_dialog.dart';

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
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
