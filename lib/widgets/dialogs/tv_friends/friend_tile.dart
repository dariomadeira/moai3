part of '../tv_friends_dialog.dart';

class _FriendTile extends StatefulWidget {
  final FriendInfo friend;
  final FocusNode focusNode;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyRightAcross;
  final VoidCallback onDelete;

  const _FriendTile({
    super.key,
    required this.friend,
    required this.focusNode,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyRightAcross,
    required this.onDelete,
  });

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _FriendTile oldWidget) {
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
        : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    final borderColor = isFocused
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.12);

    final hasNickname = widget.friend.nickname != null &&
        widget.friend.nickname!.trim().isNotEmpty;
    final displayName =
        hasNickname ? widget.friend.nickname! : widget.friend.userCode;

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
          if (key == LogicalKeyboardKey.arrowRight) {
            widget.onKeyRightAcross();
            return KeyEventResult.handled;
          }
          if (TvKeyHandler.isActionKey(key)) {
            widget.onDelete();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onDelete,
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
                      MoaiIcons.personRounded,
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
                      Row(
                        children: [
                          Text(
                            widget.friend.userCode,
                            style: MoaiText.body(
                              context,
                              color: descColor,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? scheme.onPrimary.withValues(alpha: 0.22)
                                  : widget.friend.isOnline
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.friend.isOnline
                                        ? Colors.greenAccent.shade400
                                        : scheme.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  widget.friend.isOnline
                                      ? LocaleKeys.friends_status_online.tr()
                                      : LocaleKeys.friends_status_offline.tr(),
                                  style: MoaiText.body(
                                    context,
                                    color: isFocused
                                        ? scheme.onPrimary
                                        : widget.friend.isOnline
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurfaceVariant,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.friend.displayChannelName != null) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? scheme.onPrimary.withValues(alpha: 0.22)
                                      : scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      MoaiIcons.tvRounded,
                                      size: 8.5,
                                      color: isFocused
                                          ? scheme.onPrimary
                                          : scheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        widget.friend.displayChannelName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MoaiText.body(
                                          context,
                                          color: isFocused
                                              ? scheme.onPrimary
                                              : scheme.onTertiaryContainer,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Botón de eliminar con estilo idéntico al Administrador de Extensiones
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? scheme.primaryContainer
                        : scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    MoaiIcons.deleteOutlineRounded,
                    size: 15,
                    color: isFocused
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
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
