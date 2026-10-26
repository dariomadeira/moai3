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
            // Sólo un OK nuevo: las repeticiones de un OK que se mantuvo
            // antes de abrir el panel no aceptan solicitudes.
            if (event is KeyDownEvent && !widget.isLoading) {
              widget.onAccept();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onAccept,
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
                    MoaiIcons.personAdd,
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
                      Text(
                        widget.request.userCode,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Aceptar: la acción de la fila, en el acento (pleno con foco).
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: isFocused
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.transparent),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(scheme.primary, Colors.white, 0.18)!,
                              scheme.primary,
                            ],
                          ),
                        )
                      : moaiGlassChipDecoration(
                          scheme,
                          radius: 8,
                          highlighted: true,
                        ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        MoaiIcons.check,
                        size: MoaiIconSizes.xs,
                        color: isFocused ? scheme.onPrimary : scheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        LocaleKeys.friends_accept_button.tr(),
                        style: MoaiText.body(
                          context,
                          color: isFocused ? scheme.onPrimary : scheme.primary,
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
