import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Manejo compartido de teclas direccionales para widgets TV (como moaiSmart).
abstract final class TvKeyHandler {
  static KeyEventResult handleDirectional({
    required LogicalKeyboardKey key,
    VoidCallback? onLeft,
    VoidCallback? onRight,
    VoidCallback? onUp,
    VoidCallback? onDown,
  }) {
    if (key == LogicalKeyboardKey.arrowRight && onRight != null) {
      onRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && onLeft != null) {
      onLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && onUp != null) {
      onUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && onDown != null) {
      onDown();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static bool isActionKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space;
  }
}

