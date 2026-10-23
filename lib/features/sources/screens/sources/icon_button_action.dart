part of '../sources_screen.dart';

class _IconButtonAction extends StatefulWidget {
  final FocusNode focusNode;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool parentFocused;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;

  const _IconButtonAction({
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.parentFocused,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyLeft,
    this.onKeyRight,
  });

  @override
  State<_IconButtonAction> createState() => _IconButtonActionState();
}

class _IconButtonActionState extends State<_IconButtonAction> {
  late bool _isFocused;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final Color bg;
    final Color fg;

    if (_isFocused) {
      if (widget.parentFocused) {
        bg = scheme.onPrimary;
        fg = scheme.primary;
      } else {
        bg = scheme.primary;
        fg = scheme.onPrimary;
      }
    } else {
      if (widget.parentFocused) {
        bg = scheme.onPrimary.withValues(alpha: 0.16);
        fg = scheme.onPrimary;
      } else {
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
        fg = scheme.onSurfaceVariant;
      }
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (TvKeyHandler.isActionKey(key)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(widget.icon, color: fg, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
