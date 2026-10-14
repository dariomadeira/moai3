import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Selector segmentado tipo píldora para menús TV.
///
/// En reposo usa el color del tema ([ColorScheme.primary]).
/// Con la fila enfocada (fondo `primary` del [TvTile]), invierte a
/// [ColorScheme.onPrimary] para mantener contraste legible.
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
    final focused = widget.isFocused;

    // Sobre fila enfocada (fondo primary) usamos onPrimary; en reposo, surface.
    final trackBg = focused
        ? scheme.onPrimary.withValues(alpha: 0.16)
        : scheme.surface;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: trackBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widget.options.map((option) {
          final isSelected = option == widget.selectedValue;
          final isHovered = option == _hoveredItem;

          late final Color bg;
          late final Color border;
          late final Color fg;

          if (focused) {
            if (isSelected) {
              bg = scheme.onPrimary;
              fg = accent;
              border = scheme.onPrimary;
            } else if (isHovered) {
              bg = scheme.onPrimary.withValues(alpha: 0.18);
              border = scheme.onPrimary.withValues(alpha: 0.45);
              fg = scheme.onPrimary;
            } else {
              bg = Colors.transparent;
              border = Colors.transparent;
              fg = scheme.onPrimary.withValues(alpha: 0.78);
            }
          } else if (isSelected) {
            bg = scheme.primaryContainer;
            fg = scheme.onPrimaryContainer;
            border = Colors.transparent;
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
                    width: isSelected && focused ? 2.0 : 1.0,
                  ),
                ),
                child: Text(
                  widget.labelBuilder(option),
                  style: MoaiText.body(
                    context,
                    color: fg,
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
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
