import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Pastilla chica de cristal con un ícono (las acciones de los encabezados
/// de las listas: crear marcador, limpiar favoritos, favorito). En reposo,
/// cristal blanco con filo de luz; con foco, el acento con brillo y halo y
/// un zoom leve. [highlighted] marca un estado activo sin foco (el canal ya
/// es favorito): cristal teñido y el ícono en el acento.
class TvGlassIconPill extends StatefulWidget {
  const TvGlassIconPill({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.onPressed,
    this.highlighted = false,
    this.tooltip,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  final FocusNode focusNode;
  final IconData icon;
  final VoidCallback onPressed;
  final bool highlighted;
  final String? tooltip;

  /// Cada flecha con su acción se consume; sin acción, sigue de largo.
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  @override
  State<TvGlassIconPill> createState() => _TvGlassIconPillState();
}

class _TvGlassIconPillState extends State<TvGlassIconPill> {
  late bool _isFocused = widget.focusNode.hasFocus;

  @override
  void didUpdateWidget(covariant TvGlassIconPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final action = switch (key) {
      LogicalKeyboardKey.arrowLeft => widget.onKeyLeft,
      LogicalKeyboardKey.arrowRight => widget.onKeyRight,
      LogicalKeyboardKey.arrowUp => widget.onKeyUp,
      LogicalKeyboardKey.arrowDown => widget.onKeyDown,
      _ => TvKeyHandler.isActionKey(key) ? widget.onPressed : null,
    };
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = _isFocused || widget.focusNode.hasFocus;
    final iconColor = isFocused
        ? scheme.onPrimary
        : (widget.highlighted ? scheme.primary : scheme.onSurface);

    Widget pill = GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 24,
          decoration: moaiGlassButtonDecoration(
            scheme,
            focused: isFocused,
            highlighted: widget.highlighted,
          ),
          child: Center(
            child: Icon(widget.icon, color: iconColor, size: MoaiIconSizes.sm),
          ),
        ),
      ),
    );
    final tooltip = widget.tooltip;
    if (tooltip != null) pill = Tooltip(message: tooltip, child: pill);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: _onKey,
      child: pill,
    );
  }
}
