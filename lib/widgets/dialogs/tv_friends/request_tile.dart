part of '../tv_friends_dialog.dart';

class _RequestTile extends StatefulWidget {
  final FriendInfo request;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyLeftAcross;
  final VoidCallback onAccept;

  const _RequestTile({
    super.key,
    required this.request,
    required this.focusNode,
    required this.isLoading,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyLeftAcross,
    required this.onAccept,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _RequestTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;

    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.tertiaryContainer;
    final iconColor = isFocused
        ? scheme.onPrimary
        : scheme.onTertiaryContainer;

    final borderColor = isFocused
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.12);

    final hasNickname = widget.request.nickname != null &&
        widget.request.nickname!.trim().isNotEmpty;
    final displayName =
        hasNickname ? widget.request.nickname! : widget.request.userCode;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp) {
            widget.onKeyUp();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            widget.onKeyDown();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onKeyLeftAcross();
            return KeyEventResult.handled;
          }
          if (TvKeyHandler.isActionKey(key)) {
            if (!widget.isLoading) {
              widget.onAccept();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onAccept,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      MoaiIcons.personAdd,
                      size: 18,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.request.userCode,
                        style: MoaiText.body(
                          context,
                          color: descColor,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Botón de Aceptar compacto con estilo de Administrador de Extensiones
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? scheme.primaryContainer
                        : scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        MoaiIcons.check,
                        size: 12,
                        color: isFocused
                            ? scheme.onPrimaryContainer
                            : scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        LocaleKeys.friends_accept_button.tr(),
                        style: MoaiText.body(
                          context,
                          color: isFocused
                              ? scheme.onPrimaryContainer
                              : scheme.onSecondaryContainer,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
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
    );
  }
}
