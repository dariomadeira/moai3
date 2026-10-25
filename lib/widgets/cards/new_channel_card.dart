import 'package:flutter/material.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_metrics.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';

/// Ítem de canal: mismo layout que [TvIconListCard], leading rectangular con logo.
class NewChannelCard extends StatefulWidget {
  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onLongPress;

  const NewChannelCard({
    super.key,
    required this.channel,
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
  State<NewChannelCard> createState() => _NewChannelCardState();
}

class _NewChannelCardState extends State<NewChannelCard> {
  bool _isFocused = false;
  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant NewChannelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    final itemStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: isFocused,
      selected: widget.isSelected,
    );
    // Sobre el fondo ambiente el ítem es de cristal, como [TvIconListCard];
    // el foco no rellena, así que texto y etiqueta no cambian.
    final glass = MoaiGlassScope.enabledOf(context);
    final solidFocus = isFocused && !glass;
    final labelColor = glass ? scheme.onSurface : itemStyle.foregroundColor;

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
            child: _chrome(
              glass: glass,
              isFocused: isFocused,
              itemStyle: itemStyle,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = TvListCardMetrics.forWidth(
                    constraints.maxWidth,
                  );

                  final rawTag = widget.channel.pluginTag?.trim();
                  final tag = (rawTag != null && rawTag.isNotEmpty)
                      ? rawTag.toUpperCase()
                      : null;

                  return Row(
                    children: [
                      if (metrics.logoWidth > 0) ...[
                        TvListCardLeadingLogo(
                          logoUrl: widget.channel.logoUrl,
                          width: metrics.logoWidth,
                          height: metrics.logoHeight,
                          isFocused: isFocused,
                        ),
                        SizedBox(width: metrics.gap),
                      ],
                      Expanded(
                        child: Text(
                          widget.channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.body(
                            context,
                            fontSize: constraints.maxWidth < 120 ? 10.0 : 11.5,
                            height: 1.15,
                            color: labelColor,
                            fontWeight: itemStyle.fontWeight,
                          ),
                        ),
                      ),
                      if (tag != null && constraints.maxWidth >= 130) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: solidFocus
                                ? itemStyle.foregroundColor.withValues(
                                    alpha: 0.18,
                                  )
                                : scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            maxLines: 1,
                            style: MoaiText.body(
                              context,
                              fontSize: 9.0,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                              letterSpacing: 0.5,
                              color: solidFocus
                                  ? itemStyle.foregroundColor
                                  : scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Fondo del ítem: cristal (foco con borde del acento, elegido teñido) o
  /// el estilo opaco de siempre.
  Widget _chrome({
    required bool glass,
    required bool isFocused,
    required TvListCardStyle itemStyle,
    required Widget child,
  }) {
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);
    if (glass) {
      return MoaiGlass(
        borderRadius: 12,
        elevated: false,
        solid: true,
        tint: widget.isSelected ? context.scheme.primary : null,
        focused: isFocused,
        padding: padding,
        child: child,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: padding,
      decoration: BoxDecoration(
        color: itemStyle.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: itemStyle.border,
      ),
      child: child,
    );
  }
}
