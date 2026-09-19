import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_layouts.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
import 'package:moai3/widgets/tv_input/tv_on_screen_keyboard.dart';

Future<String?> showTvTextInput(
  BuildContext context, {
  required String title,
  required String initialValue,
  required TvKeyboardType keyboardType,
  String? hint,
  String? doneLabel,
  int? maxLength,
}) {
  // Root navigator: el dialog queda por encima de GoRouter/Home.
  return showGeneralDialog<String>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'keyboard_close_barrier'.tr(),
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _TvTextInputSheet(
        title: title,
        initialValue: initialValue,
        keyboardType: keyboardType,
        hint: hint,
        doneLabel: doneLabel ?? 'keyboard_done'.tr(),
        maxLength: maxLength,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _TvTextInputSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final TvKeyboardType keyboardType;
  final String? hint;
  final String doneLabel;
  final int? maxLength;

  const _TvTextInputSheet({
    required this.title,
    required this.initialValue,
    required this.keyboardType,
    required this.hint,
    required this.doneLabel,
    required this.maxLength,
  });

  @override
  State<_TvTextInputSheet> createState() => _TvTextInputSheetState();
}

class _TvTextInputSheetState extends State<_TvTextInputSheet> {
  late final TextEditingController _controller;
  late final ScrollController _textScrollController;

  /// Evita doble cierre si Cancelar + pop de sistema llegan juntos.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _textScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCursor());
  }

  @override
  void dispose() {
    _controller.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  void _scrollToCursor() {
    if (!_textScrollController.hasClients) return;
    final text = _controller.text;
    if (text.isEmpty) {
      _textScrollController.jumpTo(0);
      return;
    }
    final sel = _controller.selection;
    final offset = sel.baseOffset >= 0 ? sel.baseOffset : text.length;
    final ratio = (offset / text.length).clamp(0.0, 1.0);
    final maxExtent = _textScrollController.position.maxScrollExtent;
    final target = maxExtent * ratio;

    if ((_textScrollController.offset - target).abs() > 1.0) {
      _textScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _applyKey(TvKeyDef key) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;

    String next;
    int cursor;

    switch (key.action) {
      case TvKeyAction.backspace:
        if (start != end) {
          next = text.replaceRange(start, end, '');
          cursor = start;
        } else if (start > 0) {
          next = text.replaceRange(start - 1, start, '');
          cursor = start - 1;
        } else {
          return;
        }
      case TvKeyAction.clear:
        next = '';
        cursor = 0;
      case TvKeyAction.space:
        next = text.replaceRange(start, end, ' ');
        cursor = start + 1;
      case TvKeyAction.character:
        final ch = key.character ?? '';
        if (ch.isEmpty) return;
        next = text.replaceRange(start, end, ch);
        cursor = start + ch.length;
      default:
        return;
    }

    if (widget.maxLength != null && next.length > widget.maxLength!) {
      return;
    }

    setState(() {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: cursor),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCursor());
  }

  void _dismiss([String? result]) {
    if (_closing || !mounted) return;
    _closing = true;
    // Mismo navigator que showGeneralDialog (root).
    Navigator.of(context, rootNavigator: true).pop(result);
  }

  void _cancel() => _dismiss();

  void _submit() => _dismiss(_controller.text);

  bool get _isCompact =>
      widget.keyboardType == TvKeyboardType.ip ||
      widget.keyboardType == TvKeyboardType.port ||
      widget.keyboardType == TvKeyboardType.number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _controller.text;
    final isHint = text.isEmpty;
    final sel = _controller.selection;
    final cursor =
        sel.baseOffset >= 0 ? sel.baseOffset.clamp(0, text.length) : text.length;
    final beforeCursor = isHint ? (widget.hint ?? ' ') : text.substring(0, cursor);
    final afterCursor = isHint ? '' : text.substring(cursor);
    final width = _isCompact ? 268.0 : 520.0;

    // IMPORTANTE (Android TV + GoRouter):
    // Back llega como pop de sistema. Solo PopScope debe cerrar el dialog.
    // NO bindar goBack → Navigator.pop: eso + el pop de sistema saca Home/app.
    // En /server no se nota porque ServerConfig tiene canPop:false.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SafeArea(
        child: Center(
          child: Material(
            color: scheme.surfaceContainerLow,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 28,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    controller: _textScrollController,
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                      ),
                                      child: Center(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: beforeCursor,
                                                style: MoaiText.body(
                                                  context,
                                                  color: isHint
                                                      ? scheme.onSurfaceVariant
                                                      : scheme.onSurface,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (!isHint) ...[
                                                WidgetSpan(
                                                  alignment:
                                                      PlaceholderAlignment.middle,
                                                  child: _BlinkingCursor(
                                                    color: scheme.primary,
                                                    height: 20,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: afterCursor,
                                                  style: MoaiText.body(
                                                    context,
                                                    color: scheme.onSurface,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TvOnScreenKeyboard(
                      type: widget.keyboardType,
                      doneLabel: widget.doneLabel,
                      onKey: _applyKey,
                      onCancel: _cancel,
                      onDone: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  final double height;

  const _BlinkingCursor({
    required this.color,
    required this.height,
  });

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

