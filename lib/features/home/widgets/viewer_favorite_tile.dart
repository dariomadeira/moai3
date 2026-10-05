import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:provider/provider.dart';

class ViewerFavoriteTile extends StatefulWidget {
  final Channel channel;
  final bool isSelected;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const ViewerFavoriteTile({
    super.key,
    required this.channel,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<ViewerFavoriteTile> createState() => _ViewerFavoriteTileState();
}

class _ViewerFavoriteTileState extends State<ViewerFavoriteTile> {
  bool _isFocused = false;
  late bool _logoOk;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
    _logoOk = widget.channel.logoUrl.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ViewerFavoriteTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
    if (widget.channel.id != oldWidget.channel.id ||
        widget.channel.logoUrl != oldWidget.channel.logoUrl) {
      _logoOk = widget.channel.logoUrl.trim().isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final showLabelSetting = () {
      try {
        return context.select((TvSettingsProvider s) => s.showChannelLabels);
      } catch (_) {
        return false;
      }
    }();
    final showLabel = showLabelSetting || !_logoOk;
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    // Foco en favoritos: sin relleno primary; borde = color que antes era el fondo (scheme.primary), idéntico a ChannelGridTile.
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

    final rawTag = widget.channel.pluginTag?.trim();
    final tag = (rawTag != null && rawTag.isNotEmpty)
        ? rawTag.toUpperCase()
        : null;

    return SizedBox(
      width: TvLayoutConstants.viewerFavoriteTileWidth,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: itemStyle.backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: itemStyle.border,
            ),
            child: Column(
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
                          logoUrl: widget.channel.logoUrl,
                          width: side,
                          height: side,
                          isFocused: isFocused,
                          contentPadding: const EdgeInsets.all(3),
                          onLogoResolved: (ok) {
                            if (!mounted || _logoOk == ok) return;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _logoOk != ok) {
                                setState(() => _logoOk = ok);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: itemStyle.foregroundColor,
                      fontSize: 9.5,
                      fontWeight: itemStyle.fontWeight,
                    ),
                  ),
                ],
                if (tag != null) ...[
                  const SizedBox(height: 2),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isFocused
                            ? itemStyle.foregroundColor.withValues(alpha: 0.2)
                            : scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        maxLines: 1,
                        style: MoaiText.body(
                          context,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          letterSpacing: 0.4,
                          color: isFocused
                              ? itemStyle.foregroundColor
                              : scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
