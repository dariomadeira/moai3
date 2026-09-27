import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';

/// Encabezado estándar para paneles TV (título + subtítulo).
///
/// El botón de volver solo aparece si se pasan [backFocusNode] y [onBack].
class TvPanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? extraContent;
  final EdgeInsetsGeometry padding;
  final FocusNode? backFocusNode;
  final VoidCallback? onBack;
  final VoidCallback? onBackKeyDown;

  const TvPanelHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.extraContent,
    this.padding = const EdgeInsets.only(left: 6, top: 4, bottom: 6),
    this.backFocusNode,
    this.onBack,
    this.onBackKeyDown,
  });

  bool get _showsBack => backFocusNode != null && onBack != null;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MoaiText.display(
            context,
            color: scheme.onSurface,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: MoaiText.body(
            context,
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.2,
          ),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showsBack)
            Row(
              children: [
                _HeaderBackButton(
                  focusNode: backFocusNode!,
                  onPressed: onBack!,
                  onKeyDown: onBackKeyDown,
                ),
                const SizedBox(width: 12),
                Expanded(child: titles),
              ],
            )
          else
            titles,
          if (extraContent != null) ...[
            const SizedBox(height: 12),
            extraContent!,
          ],
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback? onKeyDown;

  const _HeaderBackButton({
    required this.focusNode,
    required this.onPressed,
    this.onKeyDown,
  });

  @override
  State<_HeaderBackButton> createState() => _HeaderBackButtonState();
}

class _HeaderBackButtonState extends State<_HeaderBackButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final fg = _isFocused ? scheme.onPrimary : scheme.onSurface;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (TvKeyHandler.isActionKey(key)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return TvKeyHandler.handleDirectional(
          key: key,
          onDown: widget.onKeyDown,
          onLeft: widget.onPressed,
        );
      },
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.arrow_back_outlined,
              color: fg,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
