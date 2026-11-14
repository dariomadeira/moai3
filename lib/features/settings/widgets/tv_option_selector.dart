import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Selector segmentado tipo píldora para menús TV.
///
/// En reposo usa el color del tema ([ColorScheme.primary]).
/// Con la fila enfocada (fondo `primary` del [TvTile]), invierte a
/// [ColorScheme.onPrimary] para mantener contraste legible.
/// En modo edición ([isEditing]) aparecen flechas a los lados: ← →
/// cambian la opción.
class TvOptionSelector<T> extends StatefulWidget {
  final List<T> options;
  final T selectedValue;
  final ValueChanged<T> onSelect;
  final String Function(T item) labelBuilder;
  final bool isFocused;
  final bool isEditing;
  final Color? accentColor;

  const TvOptionSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.labelBuilder,
    this.isFocused = false,
    this.isEditing = false,
    this.accentColor,
  });

  @override
  State<TvOptionSelector<T>> createState() => _TvOptionSelectorState<T>();
}

class _TvOptionSelectorState<T> extends State<TvOptionSelector<T>> {
  T? _hoveredItem;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = widget.accentColor ?? scheme.primary;
    final focused = widget.isFocused;

    // Riel de cristal como la pista del switch, la opción elegida en el
    // acento y, editando, flechas del acento.
    final dark = scheme.brightness == Brightness.dark;
    final glassLine = dark ? Colors.white : scheme.onSurface;

    final BoxDecoration trackDecoration;
    if (!dark) {
      // Como un botón de cristal sin foco, pero más blanco que la ficha
      // (que va al 45 %): el riel se lee como una pieza de vidrio encima.
      trackDecoration = BoxDecoration(
        color: const Color(0x99FFFFFF), // blanco al 60 %
        borderRadius: BorderRadius.circular(999),
        // Editando, el mismo filo: las flechas ya avisan que se puede
        // cambiar.
        border: Border.all(
          color: const Color(0xB3FFFFFF), // filo de luz al 70 %
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000), // negro al 8 %: lo despega apenas
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      );
    } else {
      trackDecoration = BoxDecoration(
        color: glassLine.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: glassLine.withValues(alpha: 0.14)),
      );
    }

    final track = Container(
      padding: const EdgeInsets.all(2),
      decoration: trackDecoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.options.map((option) {
          final isSelected = option == widget.selectedValue;
          final isHovered = option == _hoveredItem;

          const border = Colors.transparent;
          final Color bg;
          final Color fg;
          Gradient? gradient;
          if (isSelected) {
            bg = accent;
            gradient = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(accent, Colors.white, 0.15)!, accent],
            );
            fg = scheme.onPrimary;
          } else {
            bg = isHovered
                ? glassLine.withValues(alpha: 0.08)
                : Colors.transparent;
            fg = isHovered ? scheme.onSurface : scheme.onSurfaceVariant;
          }

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hoveredItem = option),
            onExit: (_) => setState(() => _hoveredItem = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  // 4 px más alto que el switch.
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: border,
                    width: isSelected && focused ? 2.0 : 1.0,
                  ),
                ),
                child: Text(
                  widget.labelBuilder(option),
                  style: MoaiText.body(
                    context,
                    color: fg,
                    fontSize: MoaiText.sizeCaption,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (!widget.isEditing) return track;
    final arrowColor = scheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(MoaiIcons.chevronLeft, size: MoaiIconSizes.sm, color: arrowColor),
        const SizedBox(width: 4),
        track,
        const SizedBox(width: 4),
        Icon(MoaiIcons.chevronRight, size: MoaiIconSizes.sm, color: arrowColor),
      ],
    );
  }
}
