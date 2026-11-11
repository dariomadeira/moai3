import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_focus_ring.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

/// Ficha de un grupo de canales (país, categoría…) con los estados del rail:
///  - Sin elegir: cristal discreto, como las filas de Ajustes.
///  - Elegido: el vidrio blanco del destino elegido del rail, con el check.
///  - Foco: como en Ajustes y en la grilla de canales, sólo el borde del
///    color de la sección con una sombrita corta; el relleno no cambia.
/// Ocupa todo el alto que le da su lugar en la lista.
class TvGroupTile extends StatefulWidget {
  final String label;
  final IconData icon;

  /// Reemplaza al ícono (p. ej. la bandera del país).
  final Widget? leading;
  final bool isSelected;

  /// Color del foco y del check; por defecto, el acento del tema.
  final Color? accent;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const TvGroupTile({
    super.key,
    required this.label,
    required this.icon,
    this.leading,
    required this.isSelected,
    this.accent,
    required this.focusNode,
    required this.onTap,
    this.onLongPress,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const double _radius = 16;

  @override
  State<TvGroupTile> createState() => _TvGroupTileState();
}

class _TvGroupTileState extends State<TvGroupTile> {
  late bool _isFocused = widget.focusNode.hasFocus;

  @override
  void didUpdateWidget(covariant TvGroupTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final focused = _isFocused || widget.focusNode.hasFocus;
    final selected = widget.isSelected;
    const padding = EdgeInsets.symmetric(horizontal: 14);

    final content = Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child:
                widget.leading ??
                Icon(
                  widget.icon,
                  size: MoaiIconSizes.lg,
                  color: widget.accent ?? Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 12),
          Icon(
            MoaiIcons.selectedCheck,
            size: MoaiIconSizes.lg,
            color: widget.accent ?? Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );

    Widget chrome;
    if (selected) {
      chrome = Container(
        padding: padding,
        decoration: moaiGlassButtonDecoration(
          scheme,
          focused: false,
          radius: TvGroupTile._radius,
        ),
        child: content,
      );
    } else {
      chrome = MoaiGlass(
        borderRadius: TvGroupTile._radius,
        elevated: false,
        solid: true,
        padding: padding,
        child: content,
      );
    }
    chrome = TvFocusRing(
      focused: focused,
      color: widget.accent ?? Theme.of(context).colorScheme.primary,
      radius: TvGroupTile._radius,
      child: chrome,
    );

    return Semantics(
      label: widget.label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: TvPressDetector(
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _isFocused = v),
        onPress: widget.onTap,
        onLongPress: widget.onLongPress,
        onUp: widget.onKeyUp,
        onDown: widget.onKeyDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.focusNode.requestFocus();
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          child: SizedBox.expand(child: chrome),
        ),
      ),
    );
  }
}
