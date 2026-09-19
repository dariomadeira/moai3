import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_metrics.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';

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
  Timer? _longPressTimer;
  bool _longPressTriggered = false;
  bool _isKeyDown = false;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          final key = event.logicalKey;
          final isActionButton =
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.gameButtonA ||
              key == LogicalKeyboardKey.space;

          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.arrowLeft) {
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight &&
                  widget.onKeyRight != null) {
                widget.onKeyRight!();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowLeft &&
                  widget.onKeyLeft != null) {
                widget.onKeyLeft!();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            } else if (key == LogicalKeyboardKey.arrowUp) {
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
          child: SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: itemStyle.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: itemStyle.border,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics =
                      TvListCardMetrics.forWidth(constraints.maxWidth);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                            color: itemStyle.foregroundColor,
                            fontWeight: itemStyle.fontWeight,
                          ),
                        ),
                      ),
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
}

