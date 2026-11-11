import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/channel_source_tag.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_focus_ring.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';

/// Ficha de canal de la grilla (2 columnas), de Buscar y de la barra de
/// Favoritos. El elegido lleva el check abajo a la derecha (sin teñir) y el
/// foco pone el borde del acento.
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

  /// Separación entre fichas (la mitad arriba y la mitad abajo de cada una;
  /// entre columnas, entera).
  static const double gap = 8;

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
    final selected = widget.isSelected;
    // El foco va en el acento (el verde de TV queda sólo en el rail).
    final accent = scheme.primary;
    final baseStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: false,
      // El elegido no se tiñe: lo marca el check de abajo.
      selected: false,
    );
    final itemStyle = isFocused
        ? TvListCardStyle(
            backgroundColor: baseStyle.backgroundColor,
            foregroundColor: baseStyle.foregroundColor,
            iconColor: baseStyle.iconColor,
            fontWeight: FontWeight.w700,
            border: Border.all(color: accent, width: 2),
          )
        : baseStyle;

    final rawTag = widget.channel.pluginTag?.trim();
    final tag = (rawTag != null && rawTag.isNotEmpty)
        ? rawTag.toUpperCase()
        : null;

    final labelColor = scheme.onSurface;
    const padding = EdgeInsets.symmetric(horizontal: 4, vertical: 4);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return Center(
                child: TvListCardLeadingLogo(
                  key: ValueKey(widget.channel.logoUrl),
                  logoUrl: widget.channel.logoUrl,
                  width: side,
                  height: side,
                  isFocused: isFocused,
                  contentPadding: const EdgeInsets.all(3),
                  // Sin logo: el ícono en el acento, como los de Categorías.
                  fallbackColor: accent,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              color: labelColor,
              fontSize: 10.5,
              fontWeight: itemStyle.fontWeight,
            ),
          ),
        ],
        // Fila de abajo: la etiqueta de origen centrada y, en el elegido, el
        // check a la derecha. Va fuera del lugar del logo: nunca lo pisa.
        if (tag != null || selected) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: 21,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (tag != null)
                  ChannelSourceTag(channel: widget.channel, tag: tag),
                if (selected)
                  Positioned(
                    right: 4,
                    child: Icon(
                      MoaiIcons.selectedCheck,
                      size: MoaiIconSizes.sm,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
          // Aire abajo: que la fila no quede pegada al borde.
          const SizedBox(height: 4),
        ],
      ],
    );

    final Widget chrome = TvFocusRing(
      // Foco: borde del acento y una sombrita del mismo color, como los
      // botones de las listas.
      focused: isFocused,
      color: accent,
      child: MoaiGlass(
        borderRadius: 10,
        elevated: false,
        solid: true,
        padding: padding,
        child: content,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ChannelGridTile.gap / 2),
      child: Semantics(
        label: widget.channel.name,
        button: true,
        selected: widget.isSelected,
        excludeSemantics: true,
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
            child: chrome,
          ),
        ),
      ),
    );
  }
}
