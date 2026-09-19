import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// D-pad focus wrapper for the player area.
///
/// Non-fullscreen: Select → fullscreen, Left → exit to list, Up → favorites.
/// Fullscreen: any navigation/select key exits fullscreen.
class TvViewerFocusWrapper extends StatelessWidget {
  final FocusNode? focusNode;
  final bool effectiveFullScreen;
  final ValueChanged<bool>? onFullScreenChanged;
  final VoidCallback? onExitFullScreen;
  final VoidCallback? onRequestListFocus;
  final VoidCallback? onRequestUpFocus;
  final ValueChanged<bool>? onFocusChange;
  final Widget child;

  const TvViewerFocusWrapper({
    super.key,
    this.focusNode,
    required this.effectiveFullScreen,
    this.onFullScreenChanged,
    this.onExitFullScreen,
    this.onRequestListFocus,
    this.onRequestUpFocus,
    this.onFocusChange,
    required this.child,
  });

  KeyEventResult _handleKey(LogicalKeyboardKey key) {
    if (effectiveFullScreen) {
      if (key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack) {
        if (onFullScreenChanged != null) {
          onFullScreenChanged!(false);
        } else {
          onExitFullScreen?.call();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      onFullScreenChanged?.call(true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      onRequestListFocus?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (onRequestUpFocus != null) {
        onRequestUpFocus!();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Smart: ↓ del viewer = ignored (no saltar a favs).
    if (key == LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          return _handleKey(event.logicalKey);
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

