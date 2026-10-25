import 'package:flutter/material.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';

/// Tile de canal para grilla 2 columnas: logo arriba, nombre abajo.
class ChannelGridTile extends StatefulWidget {
  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final bool Function()? onKeyLeft;
  final bool Function()? onKeyRight;
  final VoidCallback? onLongPress;

  const ChannelGridTile({
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
  State<ChannelGridTile> createState() => _ChannelGridTileState();
}

class _ChannelGridTileState extends State<ChannelGridTile> {
  bool _isFocused = false;

  /// Optimistic: URL no vacía hasta que el logo confirme error/éxito.
  late bool _logoOk;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
    _logoOk = !TvListCardLeadingLogo.isUrlFailed(widget.channel.logoUrl);
  }

  @override
  void didUpdateWidget(covariant ChannelGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
    if (widget.channel.id != oldWidget.channel.id ||
        widget.channel.logoUrl != oldWidget.channel.logoUrl) {
      _logoOk = !TvListCardLeadingLogo.isUrlFailed(widget.channel.logoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final showLabelSetting = context.select<TvSettingsProvider?, bool>(
      (s) => s?.showChannelLabels ?? false,
    );
    final showLabel = showLabelSetting || !_logoOk;
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    // Canales: foco SOLO con borde primary (sin relleno).
    final baseStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: false,
      selected: widget.isSelected,
    );
    final itemStyle = isFocused
        ? TvListCardStyle(
            backgroundColor: baseStyle.backgroundColor,
            foregroundColor: baseStyle.foregroundColor,
            iconColor: baseStyle.iconColor,
            fontWeight: FontWeight.w700,
            border: Border.all(color: scheme.primary, width: 2),
          )
        : baseStyle;
    // Sobre el fondo ambiente el tile es de cristal; fuera, estilo opaco.
    final glass = MoaiGlassScope.enabledOf(context);
    // En cristal el foco no rellena el tile: texto y etiqueta no cambian.
    final solidFocus = isFocused && !glass;
    final labelColor = glass ? scheme.onSurface : itemStyle.foregroundColor;
    const padding = EdgeInsets.fromLTRB(6, 6, 6, 4);

    final rawTag = widget.channel.pluginTag?.trim();
    final tag = (rawTag != null && rawTag.isNotEmpty)
        ? rawTag.toUpperCase()
        : null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth;
              final logoH = (constraints.maxHeight).clamp(0.0, side);
              return Center(
                child: TvListCardLeadingLogo(
                  key: ValueKey(widget.channel.logoUrl),
                  logoUrl: widget.channel.logoUrl,
                  width: side,
                  height: logoH,
                  isFocused: isFocused,
                  onLogoResolved: (ok) {
                    if (mounted && _logoOk != ok) {
                      setState(() => _logoOk = ok);
                    }
                  },
                ),
              );
            },
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            widget.channel.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              fontSize: 11,
              height: 1.12,
              color: labelColor,
              fontWeight: itemStyle.fontWeight,
            ),
          ),
        ],
        if (tag != null) ...[
          const SizedBox(height: 3),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: solidFocus
                    ? itemStyle.foregroundColor.withValues(alpha: 0.2)
                    : scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag,
                maxLines: 1,
                style: MoaiText.body(
                  context,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                  letterSpacing: 0.4,
                  color: solidFocus
                      ? itemStyle.foregroundColor
                      : scheme.onTertiaryContainer,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TvPressDetector(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onPress: widget.onTap,
        onLongPress: widget.onLongPress,
        onLeft: widget.onKeyLeft,
        onRight: widget.onKeyRight,
        onUp: widget.onKeyUp,
        onDown: widget.onKeyDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.focusNode?.requestFocus();
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          child: glass
              // Mismo criterio que [TvIconListCard]: foco con borde del
              // acento y tinte suave; el canal elegido va teñido.
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
    );
  }
}
