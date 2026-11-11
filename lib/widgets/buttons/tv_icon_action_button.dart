import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Botón de ícono redondo de las filas de listas TV (actualizar, borrar…).
///
/// Cambia de colores según tenga el foco y según la fila padre lo tenga
/// ([parentFocused]). Las flechas llaman a los callbacks `onKey*`.
class TvIconActionButton extends StatefulWidget {
  final FocusNode focusNode;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool parentFocused;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;

  /// Acción destructiva (borrar): el ícono en rojo y, con foco, el botón
  /// en rojo con halo en vez del acento.
  final bool destructive;

  const TvIconActionButton({
    super.key,
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.parentFocused,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyLeft,
    this.onKeyRight,
    this.destructive = false,
  });

  @override
  State<TvIconActionButton> createState() => _TvIconActionButtonState();
}

class _TvIconActionButtonState extends State<TvIconActionButton> {
  late bool _isFocused;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  /// El destructivo con foco (borrar), igual en los dos modos: el rojo de
  /// error del tema claro con el ícono blanco. El del tema oscuro es un rosa
  /// claro (para leerse como texto) y relleno quedaba lavado.
  static const Color _destructiveFill = Color(0xFFBA1A1A);
  static const Color _onDestructiveFill = Colors.white;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Cristal: tenue en reposo (la fila no se rellena al enfocarse, así que
    // [parentFocused] no cambia colores); con foco, acento con brillo y halo.
    final glass = MoaiGlassScope.enabledOf(context);

    final Color bg;
    final Color fg;

    if (glass) {
      // El relleno lo da [moaiGlassButtonDecoration].
      bg = Colors.transparent;
      fg = _isFocused
          ? (widget.destructive ? _onDestructiveFill : scheme.onPrimary)
          : (widget.destructive ? scheme.error : scheme.onSurface);
    } else if (_isFocused) {
      if (widget.parentFocused) {
        bg = scheme.onPrimary;
        fg = scheme.primary;
      } else {
        bg = scheme.primary;
        fg = scheme.onPrimary;
      }
    } else {
      if (widget.parentFocused) {
        bg = scheme.onPrimary.withValues(alpha: 0.16);
        fg = scheme.onPrimary;
      } else {
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
        fg = scheme.onSurfaceVariant;
      }
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (TvKeyHandler.isActionKey(key)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: glass ? _glassButton(scheme, fg) : _solidButton(bg, fg),
      ),
    );
  }

  /// Cristal: el botón de los del Inicio (blanco con filo de luz; con foco,
  /// el acento con brillo y halo). Sin [Material]: el `Ink` se recortaba al
  /// rectángulo del Material y el halo quedaba cuadrado, con puntas.
  Widget _glassButton(ColorScheme scheme, Color fg) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 36,
        decoration: moaiGlassButtonDecoration(
          scheme,
          focused: _isFocused,
          accent: widget.destructive ? _destructiveFill : null,
        ),
        child: Icon(widget.icon, color: fg, size: MoaiIconSizes.md),
      ),
    );
  }

  Widget _solidButton(Color bg, Color fg) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(widget.icon, color: fg, size: MoaiIconSizes.md),
        ),
      ),
    );
  }
}
