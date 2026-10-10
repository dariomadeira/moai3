import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Misma ficha que [TvTile] en reposo: solo lectura, sin foco ni teclado.
class TvInfoTile extends StatelessWidget {
  final String label;
  final String? description;
  final dynamic icon;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const TvInfoTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return _TvTileChrome(
      isFocused: false,
      label: label,
      description: description,
      icon: icon,
      padding: padding,
      minHeight: minHeight,
    );
  }
}

/// Tile base enfocable y reutilizable para ítems TV (Ajustes, Menús, Formulario).
class TvTile extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final String? description;
  final dynamic icon;
  final Widget Function(BuildContext context, bool isFocused)? trailingBuilder;
  final VoidCallback? onPressed;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final FocusOnKeyEventCallback? onKeyEvent;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

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
    this.padding,
    this.minHeight,
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
    final isFocused = _isFocused || widget.focusNode.hasFocus;

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
          widget.focusNode.requestFocus();
          widget.onPressed?.call();
        },
        child: _TvTileChrome(
          isFocused: isFocused,
          label: widget.label,
          description: widget.description,
          icon: widget.icon,
          padding: widget.padding,
          minHeight: widget.minHeight,
          trailing: widget.trailingBuilder?.call(context, isFocused),
        ),
      ),
    );
  }
}

class _TvTileChrome extends StatelessWidget {
  final bool isFocused;
  final String label;
  final String? description;
  final dynamic icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const _TvTileChrome({
    required this.isFocused,
    required this.label,
    this.description,
    this.icon,
    this.trailing,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: BoxConstraints(minHeight: minHeight ?? 58),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTrailingWidth =
              (constraints.maxWidth - 100).clamp(40.0, double.infinity);

          return Row(
            children: [
              if (icon != null) ...[
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: icon is List<List<dynamic>>
                        ? AppIcon(icon: icon as List<List<dynamic>>, size: 22, color: iconColor)
                        : Icon(icon as IconData, size: 22, color: iconColor),
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
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        maxLines: 1,
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
              if (trailing != null) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: trailing,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

