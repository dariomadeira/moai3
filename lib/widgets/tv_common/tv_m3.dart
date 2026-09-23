import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';

/// Variante visual alineada al teclado TV (fills, sin bordes).
enum TvButtonVariant {
  /// CTA (p. ej. Siguiente / Guardar) → [ColorScheme.secondary].
  secondary,

  /// Acción secundaria tonal → [ColorScheme.primaryContainer].
  tonal,

  /// Superficie neutra → [ColorScheme.surfaceContainerHighest].
  surface,

  /// Acción destructiva (p. ej. Vaciar favoritos) → [ColorScheme.errorContainer].
  destructive,
}

/// Botón TV Material 3: fill + scale al foco, sin outline.
class TvFocusButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final TvButtonVariant variant;
  final bool loading;
  final double height;
  final double fontSize;
  final double radius;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowRight;

  const TvFocusButton({
    super.key,
    required this.focusNode,
    required this.label,
    required this.onPressed,
    this.onLongPress,
    this.icon,
    this.variant = TvButtonVariant.secondary,
    this.loading = false,
    this.height = 48,
    this.fontSize = 15,
    this.radius = 16,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowLeft,
    this.onArrowRight,
  });

  @override
  State<TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<TvFocusButton> {
  bool _focused = false;
  Timer? _holdTimer;
  bool _longPressHandled = false;

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
    _focused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant TvFocusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
      _focused = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _cancelHoldTimer();
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  (Color bg, Color fg) _colors(ColorScheme scheme) {
    if (_focused) {
      if (widget.variant == TvButtonVariant.destructive) {
        return (scheme.error, scheme.onError);
      }
      return (scheme.primary, scheme.onPrimary);
    }
    switch (widget.variant) {
      case TvButtonVariant.secondary:
        return (scheme.secondary, scheme.onSecondary);
      case TvButtonVariant.tonal:
        return (scheme.primaryContainer, scheme.onPrimaryContainer);
      case TvButtonVariant.surface:
        return (scheme.surfaceContainerHighest, scheme.onSurface);
      case TvButtonVariant.destructive:
        return (scheme.errorContainer, scheme.onErrorContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = _colors(scheme);
    final enabled = widget.onPressed != null && !widget.loading;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (event is KeyDownEvent) {
          if (key == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
            _cancelHoldTimer();
            widget.onArrowUp!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
            _cancelHoldTimer();
            widget.onArrowDown!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft && widget.onArrowLeft != null) {
            _cancelHoldTimer();
            widget.onArrowLeft!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight &&
              widget.onArrowRight != null) {
            _cancelHoldTimer();
            widget.onArrowRight!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            if (!enabled) return KeyEventResult.handled;
            if (widget.onLongPress != null) {
              if (_holdTimer == null && !_longPressHandled) {
                _holdTimer = Timer(const Duration(seconds: 3), () {
                  _longPressHandled = true;
                  _cancelHoldTimer();
                  widget.onLongPress!();
                });
              }
            } else {
              widget.onPressed?.call();
            }
            return KeyEventResult.handled;
          }
        } else if (event is KeyUpEvent) {
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            if (_longPressHandled) {
              _longPressHandled = false;
              _cancelHoldTimer();
              return KeyEventResult.handled;
            }
            _cancelHoldTimer();
            if (enabled) widget.onPressed?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _focused ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Material(
          color: bg,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    _cancelHoldTimer();
                    widget.onPressed?.call();
                  }
                : null,
            onLongPress: enabled && widget.onLongPress != null
                ? () {
                    _cancelHoldTimer();
                    widget.onLongPress?.call();
                  }
                : null,
            splashColor: fg.withValues(alpha: 0.12),
            child: Container(
              height: widget.height,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.loading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    )
                  else if (widget.icon != null)
                    Icon(widget.icon, size: 20, color: fg),
                  if (widget.loading || widget.icon != null)
                    const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: MoaiText.body(
                      context,
                      color: fg,
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contenedor de panel M3 (como el sheet del teclado): fill, sin sombra ni borde.
class TvPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  const TvPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

