import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/utils/context_extensions.dart';

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
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final showLabelSetting =
        context.watchOptional<TvSettingsProvider>()?.showChannelLabels ?? false;
    final showLabel = showLabelSetting || !_logoOk;
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    // Foco en grilla: sin relleno primary; borde = color que antes era el fondo.
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
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
                      color: itemStyle.foregroundColor,
                      fontWeight: itemStyle.fontWeight,
                    ),
                  ),
                ],
                if (tag != null) ...[
                  const SizedBox(height: 3),
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
