import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tile base enfocable y reutilizable para ítems TV (Ajustes, Menús, Formulario).
class TvTile extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final String? description;
  final IconData? icon;
  final Widget Function(BuildContext context, bool isFocused)? trailingBuilder;
  final VoidCallback? onPressed;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final FocusOnKeyEventCallback? onKeyEvent;

  const TvTile({
    super.key,
    required this.focusNode,
    required this.label,
    this.description,
    this.icon,
    this.trailingBuilder,
    this.onPressed,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyEvent,
  });

  @override
  State<TvTile> createState() => _TvTileState();
}

class _TvTileState extends State<TvTile> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant TvTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = _isFocused || widget.focusNode.hasFocus;
    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor =
        isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final result = widget.onKeyEvent!(node, event);
          if (result != KeyEventResult.ignored) return result;
        }

        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (TvKeyHandler.isActionKey(key)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }

        return TvKeyHandler.handleDirectional(
          key: key,
          onLeft: widget.onKeyLeft,
          onRight: widget.onKeyRight,
          onUp: widget.onKeyUp,
          onDown: widget.onKeyDown,
        );
      },
      child: GestureDetector(
        onTap: () {
          if (isFocused) {
            widget.onPressed?.call();
          } else {
            widget.focusNode.requestFocus();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxTrailingWidth =
                  (constraints.maxWidth - 100).clamp(40.0, double.infinity);

              return Row(
                children: [
                  if (widget.icon != null) ...[
                    Material(
                      color: iconBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(widget.icon!, size: 22, color: iconColor),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.body(
                            context,
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: descColor,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.trailingBuilder != null) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: widget.trailingBuilder!(context, isFocused),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

