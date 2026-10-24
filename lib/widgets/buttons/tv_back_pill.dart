import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Píldora de navegación para retroceder / Volver.
///
/// Diseñada con los tokens visuales del tab bar y el rail de Moai:
/// - En reposo: [ColorScheme.primaryContainer] y [ColorScheme.onPrimaryContainer].
/// - En foco: [ColorScheme.primary] y [ColorScheme.onPrimary].
class TvBackPill extends StatefulWidget {
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyDown;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyLeft;
  final double size;
  final double iconSize;
  final double? borderRadius;
  final String? tooltip;
  final IconData icon;

  const TvBackPill({
    super.key,
    this.focusNode,
    this.onPressed,
    this.onKeyRight,
    this.onKeyDown,
    this.onKeyUp,
    this.onKeyLeft,
    this.size = 36.0,
    this.iconSize = MoaiIconSizes.md,
    this.borderRadius,
    this.tooltip,
    this.icon = MoaiIcons.arrowBack,
  });

  @override
  State<TvBackPill> createState() => _TvBackPillState();
}

class _TvBackPillState extends State<TvBackPill> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ??
      (_internalFocusNode ??= FocusNode(debugLabel: 'tv_back_pill'));
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChange);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant TvBackPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _onFocusChange,
      );
      _effectiveFocusNode.addListener(_onFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    (widget.focusNode ?? _internalFocusNode)?.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  void _handlePress() {
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bg = _isFocused ? scheme.primary : scheme.primaryContainer;
    final iconColor = _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;
    final radius = widget.borderRadius ?? (widget.size / 2);

    return Focus(
      focusNode: _effectiveFocusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (TvKeyHandler.isActionKey(key)) {
          _handlePress();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          _handlePress();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: widget.tooltip ?? LocaleKeys.common_back.tr(),
        child: InkWell(
          onTap: _handlePress,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(widget.icon, color: iconColor, size: widget.iconSize),
          ),
        ),
      ),
    );
  }
}
