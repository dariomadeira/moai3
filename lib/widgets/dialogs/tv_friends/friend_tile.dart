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
            // Sólo un OK nuevo: las repeticiones de un OK que se mantuvo
            // para abrir el panel (micrófono de Miremos juntos) no borran.
            if (event is KeyDownEvent) widget.onDelete();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onDelete,
          // Ficha de cristal como TvTile: el foco es el borde del acento.
          child: MoaiGlass(
            borderRadius: 14,
            elevated: false,
            solid: true,
            focused: isFocused,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Icon(
                    MoaiIcons.person,
                    size: MoaiIconSizes.md,
                    color: scheme.primary.withValues(
                      alpha: isFocused ? 1 : 0.75,
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
                          color: scheme.onSurface,
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
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: moaiGlassChipDecoration(
                              scheme,
                              radius: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.friend.isOnline
                                        ? Colors.greenAccent.shade400
                                        : scheme.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.friend.isOnline
                                      ? LocaleKeys.friends_status_online.tr()
                                      : LocaleKeys.friends_status_offline.tr(),
                                  style: MoaiText.body(
                                    context,
                                    color: widget.friend.isOnline
                                        ? scheme.onSurface
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
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: moaiGlassChipDecoration(
                                  scheme,
                                  radius: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      MoaiIcons.tv,
                                      size: MoaiIconSizes.xs,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        widget.friend.displayChannelName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MoaiText.body(
                                          context,
                                          color: scheme.onSurface,
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
                // Borrar: OK sobre la fila elimina, así que con foco se pone
                // rojo para avisarlo.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: isFocused
                      ? BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: scheme.error.withValues(alpha: 0.5),
                          ),
                        )
                      : moaiGlassChipDecoration(scheme, radius: 8),
                  child: Icon(
                    MoaiIcons.delete,
                    size: MoaiIconSizes.sm,
                    color: isFocused ? scheme.error : scheme.onSurfaceVariant,
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
