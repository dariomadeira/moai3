import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:moai3/focus/tv_key_handler.dart';

/// Tiempos compartidos de las pulsaciones del control remoto.
abstract final class TvTiming {
  static const longPress = Duration(milliseconds: 800);
}

/// Foco + teclas D-pad de un ítem TV (SPEC-50 §2.10).
///
/// - OK ([TvKeyHandler.isActionKey]): [onPress] al soltar; si se mantiene
///   [TvTiming.longPress] y hay [onLongPress], se llama ese y no [onPress].
/// - ←/→: las repeticiones se bloquean; [onLeft]/[onRight] devuelven `true`
///   si consumieron la tecla.
/// - ↑/↓: se consumen solo si hay callback (incluidas las repeticiones).
class TvPressDetector extends StatefulWidget {
  const TvPressDetector({
    super.key,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.onPress,
    this.onLongPress,
    this.onLeft,
    this.onRight,
    this.onUp,
    this.onDown,
    required this.child,
  });

  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final VoidCallback? onPress;
  final VoidCallback? onLongPress;
  final bool Function()? onLeft;
  final bool Function()? onRight;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final Widget child;

  /// Adapta un callback sin retorno a [onLeft]/[onRight]: siempre consume.
  static bool Function()? consuming(VoidCallback? callback) =>
      callback == null
          ? null
          : () {
              callback();
              return true;
            };

  @override
  State<TvPressDetector> createState() => _TvPressDetectorState();
}

class _TvPressDetectorState extends State<TvPressDetector> {
  Timer? _longPressTimer;
  bool _keyDown = false;
  bool _longPressFired = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _keyDown = false;
    _longPressFired = false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;

    if (event is KeyUpEvent) {
      if (!TvKeyHandler.isActionKey(key)) return KeyEventResult.ignored;
      if (_keyDown) {
        final fired = _longPressFired;
        _reset();
        if (!fired) widget.onPress?.call();
      }
      return KeyEventResult.handled;
    }

    final isRepeat = event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      if (isRepeat) return KeyEventResult.handled;
      final handler =
          key == LogicalKeyboardKey.arrowLeft ? widget.onLeft : widget.onRight;
      return (handler?.call() ?? false)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onUp != null) {
      widget.onUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onDown != null) {
      widget.onDown!();
      return KeyEventResult.handled;
    }
    if (TvKeyHandler.isActionKey(key)) {
      if (!isRepeat && !_keyDown) {
        _keyDown = true;
        _longPressFired = false;
        if (widget.onLongPress != null) {
          _longPressTimer = Timer(TvTiming.longPress, () {
            _longPressFired = true;
            widget.onLongPress?.call();
          });
        }
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (focused) {
        // Si se pierde el foco con OK apretado no queda un tap pendiente.
        if (!focused) _reset();
        widget.onFocusChange?.call(focused);
      },
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
