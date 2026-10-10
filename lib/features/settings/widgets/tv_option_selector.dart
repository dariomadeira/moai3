import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Un selector de opciones segmentadas tipo píldora para menús TV/Desktop.
/// En estado normal (sin foco) la opción seleccionada no tiene borde.
/// Al enfocar la fila, solo el borde de la opción seleccionada se resalta dinámicamente con el color de acento del icono.
class TvOptionSelector<T> extends StatefulWidget {
  final List<T> options;
  final T selectedValue;
  final ValueChanged<T> onSelect;
  final String Function(T item) labelBuilder;
  final bool isFocused;
  final Color? accentColor;

  const TvOptionSelector({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelect,
    required this.labelBuilder,
    this.isFocused = false,
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

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.options.map((option) {
          final isSelected = option == widget.selectedValue;
          final isHovered = option == _hoveredItem;

          Color bg;
          Color border;
          Color fg;

          if (isSelected) {
            bg = accent.withValues(alpha: 0.22);
            fg = accent;
            if (widget.isFocused) {
              border = accent;
            } else {
              border = Colors.transparent;
            }
          } else if (isHovered) {
            bg = scheme.onSurface.withValues(alpha: 0.1);
            border = scheme.outline.withValues(alpha: 0.3);
            fg = scheme.onSurface;
          } else {
            bg = Colors.transparent;
            border = Colors.transparent;
            fg = scheme.onSurfaceVariant;
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
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: border,
                    width: isSelected && widget.isFocused ? 2.0 : 1.0,
                  ),
                ),
                child: Text(
                  widget.labelBuilder(option),
                  style: MoaiText.body(
                    context,
                    color: fg,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
