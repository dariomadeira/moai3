import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
import 'package:moai3/widgets/tv_input/tv_text_input_sheet.dart';

/// Campo de texto para Smart TV: Select abre teclado on-screen Material.
class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String label;
  final String? hint;
  final TvKeyboardType keyboardType;
  final TvTextInputAction textInputAction;
  final String? doneLabel;
  final int? maxLength;
  final bool enabled;
  final bool dense;
  final IconData? leadingIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final String? initialValue;

  const TvTextField({
    super.key,
    this.controller,
    this.focusNode,
    required this.label,
    this.hint,
    this.initialValue,
    this.keyboardType = TvKeyboardType.text,
    this.textInputAction = TvTextInputAction.done,
    this.doneLabel,
    this.maxLength,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.onFocusLeft,
    this.onFocusRight,
    this.onFocusUp,
    this.onFocusDown,
    this.dense = false,
    this.leadingIcon,
  });

  static Future<String?> open(
    BuildContext context, {
    required String title,
    String initialValue = '',
    TvKeyboardType keyboardType = TvKeyboardType.text,
    String? hint,
    String? doneLabel,
    int? maxLength,
  }) {
    return showTvTextInput(
      context,
      title: title,
      initialValue: initialValue,
      keyboardType: keyboardType,
      hint: hint,
      doneLabel: doneLabel,
      maxLength: maxLength,
    );
  }

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  TextEditingController? _ownedController;
  FocusNode? _ownedFocusNode;
  bool _focused = false;
  bool _opening = false;

  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;

  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue ?? '');
    }
    if (widget.focusNode == null) {
      _ownedFocusNode = FocusNode(debugLabel: 'TvTextField(${widget.label})');
    }
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChange);
    _focused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant TvTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null && widget.focusNode != null) {
        _ownedFocusNode?.dispose();
        _ownedFocusNode = null;
      } else if (oldWidget.focusNode != null && widget.focusNode == null) {
        _ownedFocusNode ??=
            FocusNode(debugLabel: 'TvTextField(${widget.label})');
      }
      _focusNode.addListener(_onFocusChange);
      _focused = _focusNode.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.removeListener(_onTextChange);
      if (oldWidget.controller == null && widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else if (oldWidget.controller != null && widget.controller == null) {
        _ownedController ??=
            TextEditingController(text: widget.initialValue ?? '');
      }
      _controller.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChange);
    _ownedController?.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  String get _doneLabel {
    switch (widget.textInputAction) {
      case TvTextInputAction.next:
        return 'keyboard_next'.tr();
      case TvTextInputAction.search:
        return 'keyboard_search'.tr();
      case TvTextInputAction.done:
        return widget.doneLabel ?? 'keyboard_done'.tr();
    }
  }

  Future<void> _openKeyboard() async {
    if (!widget.enabled || _opening) return;
    _opening = true;
    try {
      final result = await showTvTextInput(
        context,
        title: widget.label,
        initialValue: _controller.text,
        keyboardType: widget.keyboardType,
        hint: widget.hint,
        doneLabel: _doneLabel,
        maxLength: widget.maxLength,
      );
      if (!mounted) return;
      if (result == null) {
        _focusNode.requestFocus();
        return;
      }
      _controller.text = result;
      _controller.selection = TextSelection.collapsed(offset: result.length);
      widget.onChanged?.call(result);
      widget.onSubmitted?.call(result);
      _focusNode.requestFocus();
    } finally {
      _opening = false;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _openKeyboard();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && widget.onFocusLeft != null) {
      widget.onFocusLeft!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && widget.onFocusRight != null) {
      widget.onFocusRight!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && widget.onFocusUp != null) {
      widget.onFocusUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && widget.onFocusDown != null) {
      widget.onFocusDown!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hasValue = _controller.text.isNotEmpty;
    final interactive = widget.enabled;

    // Mismo lenguaje visual que SettingsActionRow: fill, icono en chip, sin trailing.
    final bg = _focused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = _focused ? scheme.onPrimary : scheme.onSurface;
    final valueColor = _focused
        ? scheme.onPrimary.withValues(alpha: hasValue ? 1 : 0.85)
        : (hasValue ? scheme.onSurfaceVariant : scheme.onSurfaceVariant);
    final iconBg = _focused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = _focused ? scheme.onPrimary : scheme.onPrimaryContainer;

    final leading = widget.leadingIcon ?? Icons.keyboard_alt_outlined;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: interactive,
      onKeyEvent: _onKey,
      child: AnimatedOpacity(
        opacity: interactive ? 1 : 0.55,
        duration: const Duration(milliseconds: 140),
        child: Material(
            color: bg,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: interactive ? _openKeyboard : null,
              splashColor: (_focused ? scheme.onPrimary : scheme.onSurface)
                  .withValues(alpha: 0.1),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.dense ? 12 : 14,
                  vertical: widget.dense ? 10 : 12,
                ),
                child: Row(
                  children: [
                    Material(
                      color: iconBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(widget.dense ? 8 : 10),
                        child: Icon(
                          leading,
                          size: widget.dense ? 20 : 22,
                          color: iconColor,
                        ),
                      ),
                    ),
                    SizedBox(width: widget.dense ? 12 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: titleColor,
                              fontSize: widget.dense ? 14 : 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasValue ? _controller.text : (widget.hint ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: valueColor,
                              fontSize: widget.dense ? 12 : 13,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}

