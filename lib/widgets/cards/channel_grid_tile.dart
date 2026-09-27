import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';

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
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _isKeyDown = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant ChannelGridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
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

    final rawTag = widget.channel.pluginTag?.trim();
    final tag = (rawTag != null && rawTag.isNotEmpty)
        ? rawTag.toUpperCase()
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          final key = event.logicalKey;
          final isActionButton = key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.gameButtonA ||
              key == LogicalKeyboardKey.space;

          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (key == LogicalKeyboardKey.arrowRight) {
              if (event is KeyRepeatEvent) return KeyEventResult.handled;
              if (widget.onKeyRight != null && widget.onKeyRight!()) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
            if (key == LogicalKeyboardKey.arrowLeft) {
              if (event is KeyRepeatEvent) return KeyEventResult.handled;
              if (widget.onKeyLeft != null && widget.onKeyLeft!()) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            }
            if (key == LogicalKeyboardKey.arrowUp) {
              if (widget.onKeyUp != null) {
                widget.onKeyUp!();
                return KeyEventResult.handled;
              }
            } else if (key == LogicalKeyboardKey.arrowDown) {
              if (widget.onKeyDown != null) {
                widget.onKeyDown!();
                return KeyEventResult.handled;
              }
            } else if (isActionButton) {
              if (event is KeyDownEvent && !_isKeyDown) {
                _isKeyDown = true;
                _longPressTriggered = false;
                _longPressTimer = Timer(const Duration(milliseconds: 800), () {
                  _longPressTriggered = true;
                  widget.onLongPress?.call();
                });
              }
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            if (isActionButton) {
              if (_isKeyDown) {
                _isKeyDown = false;
                _longPressTimer?.cancel();
                _longPressTimer = null;
                if (!_longPressTriggered) {
                  widget.onTap();
                }
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.focusNode?.requestFocus();
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
            decoration: BoxDecoration(
              color: itemStyle.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: itemStyle.border,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth;
                      final logoH = (constraints.maxHeight).clamp(0.0, side);
                      return Center(
                        child: TvListCardLeadingLogo(
                          logoUrl: widget.channel.logoUrl,
                          width: side,
                          height: logoH,
                          isFocused: isFocused,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MoaiText.body(
                    context,
                    fontSize: 11.5,
                    height: 1.15,
                    color: itemStyle.foregroundColor,
                    fontWeight: itemStyle.fontWeight,
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
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
                          fontSize: 9,
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
