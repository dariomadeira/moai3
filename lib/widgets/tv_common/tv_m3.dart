import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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

  /// Estilo cristal: en reposo cristal tenue (texto del tema, rojo si es
  /// destructivo); con foco, acento con brillo y halo como el rail.
  (Color bg, Color fg) _glassColors(ColorScheme scheme) {
    final destructive = widget.variant == TvButtonVariant.destructive;
    if (_focused) {
      return destructive
          ? (scheme.error, scheme.onError)
          : (scheme.primary, scheme.onPrimary);
    }
    return (Colors.transparent, destructive ? scheme.error : scheme.onSurface);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = MoaiGlassScope.enabledOf(context);
    final (bg, fg) = glass ? _glassColors(scheme) : _colors(scheme);
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
          if (TvKeyHandler.isActionKey(key)) {
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
          if (TvKeyHandler.isActionKey(key)) {
            if (_longPressHandled) {
              _longPressHandled = false;
              _cancelHoldTimer();
              return KeyEventResult.handled;
            }
            // Sin pulsación larga ya se disparó al apretar: soltar no repite
            // (un botón que alterna volvía a su estado). Con pulsación larga,
            // el OK corto se dispara recién acá, si el temporizador seguía.
            final pending = _holdTimer != null;
            _cancelHoldTimer();
            if (enabled && widget.onLongPress != null && pending) {
              widget.onPressed?.call();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        // En cristal el foco ya lo marcan el color y el halo; el zoom hacía que
        // el botón invadiera el margen (p. ej. en el borde de un modal).
        scale: _focused && !glass ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: _glassFrame(
          glass: glass,
          scheme: scheme,
          bg: bg,
          child: Material(
          color: glass ? Colors.transparent : bg,
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
                    Icon(widget.icon, size: MoaiIconSizes.md, color: fg),
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
      ),
    );
  }

  /// Marco del botón en estilo cristal: cristal tenue en reposo y, con foco,
  /// relleno con brillo arriba y halo. Fuera del cristal no agrega nada.
  Widget _glassFrame({
    required bool glass,
    required ColorScheme scheme,
    required Color bg,
    required Widget child,
  }) {
    if (!glass) return child;
    if (!_focused) {
      return MoaiGlass(
        borderRadius: widget.radius,
        elevated: false,
        solid: true,
        child: child,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(bg, Colors.white, 0.18)!, bg],
        ),
        boxShadow: [
          BoxShadow(color: bg.withValues(alpha: 0.4), blurRadius: 16),
        ],
      ),
      child: child,
    );
  }
}

