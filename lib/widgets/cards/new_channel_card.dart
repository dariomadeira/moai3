import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/channel_source_tag.dart';
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
    // El ítem es de cristal; el foco no rellena, así que texto y etiqueta no
    // cambian.
    final labelColor = scheme.onSurface;

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
              isFocused: isFocused,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = TvListCardMetrics.forWidth(
                    constraints.maxWidth,
                  );

                  final rawTag = widget.channel.pluginTag?.trim();
                  final tag = (rawTag != null && rawTag.isNotEmpty)
                      ? rawTag.toUpperCase()
                      : null;
                  // Con lugar, debajo del nombre: categoría y país
                  // ("Deportes · Argentina").
                  final info = constraints.maxWidth >= 220 ? _infoLine() : null;

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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.channel.name,
                              maxLines: info == null ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: MoaiText.body(
                                context,
                                fontSize: constraints.maxWidth < 120
                                    ? 10.0
                                    : (info == null ? 11.5 : 13.5),
                                height: 1.15,
                                color: labelColor,
                                fontWeight: itemStyle.fontWeight,
                              ),
                            ),
                            if (info != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                info,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MoaiText.body(
                                  context,
                                  fontSize: MoaiText.sizeCaption,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (tag != null && constraints.maxWidth >= 130) ...[
                        const SizedBox(width: 8),
                        ChannelSourceTag(channel: widget.channel, tag: tag),
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

  /// "Categoría · País", sin los "General" de relleno; null si no queda nada.
  String? _infoLine() {
    final parts = <String>{
      for (final p in [widget.channel.category, widget.channel.country])
        if (p.trim().isNotEmpty &&
            p.trim().toLowerCase() !=
                LocaleKeys.browser_group_general.tr().toLowerCase())
          p.trim(),
    };
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Fondo del ítem: cristal (foco con borde del acento, elegido teñido).
  Widget _chrome({required bool isFocused, required Widget child}) {
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 6);

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
}
