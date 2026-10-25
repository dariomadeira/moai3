import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_icon.dart';
import 'package:moai3/widgets/cards/tv_list_card_metrics.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

/// Ítem de lista TV: leading cuadrado + texto (países, categorías, etc.).
class TvIconListCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Widget? leading;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onLongPress;

  const TvIconListCard({
    super.key,
    required this.label,
    required this.icon,
    this.leading,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.onLongPress,
  });

  @override
  State<TvIconListCard> createState() => _TvIconListCardState();
}

class _TvIconListCardState extends State<TvIconListCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant TvIconListCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    final scheme = context.scheme;
    // Estilo opaco: foco con relleno primary, igual que [TvTile].
    final itemStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: isFocused,
      selected: widget.isSelected,
    );
    // Sobre el fondo ambiente el ítem es de cristal; fuera, estilo opaco.
    final glass = MoaiGlassScope.enabledOf(context);
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final metrics = TvListCardMetrics.forIconWidth(constraints.maxWidth);

        return Row(
          children: [
            widget.leading ??
                TvListCardLeadingIcon(
                  icon: widget.icon,
                  isFocused: isFocused,
                  // En cristal el ícono va suelto, como en [TvTile].
                  color: glass
                      ? scheme.primary.withValues(
                          alpha: isFocused || widget.isSelected ? 1 : 0.75,
                        )
                      : null,
                ),
            SizedBox(width: metrics.gap),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  fontSize: metrics.fontSize,
                  height: 1.2,
                  color: glass ? scheme.onSurface : itemStyle.foregroundColor,
                  fontWeight: itemStyle.fontWeight,
                ),
              ),
            ),
          ],
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvPressDetector(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onPress: widget.onTap,
        onLongPress: widget.onLongPress,
        onLeft: TvPressDetector.consuming(widget.onKeyLeft),
        onRight: TvPressDetector.consuming(widget.onKeyRight),
        onUp: widget.onKeyUp,
        onDown: widget.onKeyDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.focusNode?.requestFocus();
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          child: SizedBox(
            width: double.infinity,
            child: glass
                // Cristal discreto; el foco es el de [TvTile] (borde del
                // acento y tinte suave) y el ítem elegido va teñido.
                ? MoaiGlass(
                    borderRadius: 12,
                    elevated: false,
                    solid: true,
                    tint: widget.isSelected ? scheme.primary : null,
                    focused: isFocused,
                    padding: padding,
                    child: content,
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: padding,
                    decoration: BoxDecoration(
                      color: itemStyle.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: itemStyle.border,
                    ),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}
