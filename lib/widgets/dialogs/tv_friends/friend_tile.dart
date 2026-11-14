part of '../tv_friends_dialog.dart';

/// Un amigo en el panel Amigos, como en la tarjeta del Inicio: avatar con
/// el punto de estado, el nombre y el canal que mira, y a la derecha el logo
/// de ese canal si está en la lista propia. Si mira lo mismo que yo va
/// teñido del acento con "Con vos"; desconectado, apagado.
///
/// OK: mirar juntos (ir a su canal). OK mantenido: eliminarlo. Las
/// repeticiones de un OK que ya venía apretado (el que abrió el panel desde
/// el micrófono) no hacen nada: lo resuelve [TvPressDetector].
class _FriendTile extends StatefulWidget {
  final FriendInfo friend;
  final FocusNode focusNode;
  final bool withMe;
  final String? logoUrl;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyRightAcross;
  final VoidCallback onWatch;
  final VoidCallback onDelete;

  const _FriendTile({
    super.key,
    required this.friend,
    required this.focusNode,
    required this.withMe,
    required this.logoUrl,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyRightAcross,
    required this.onWatch,
    required this.onDelete,
  });

  /// Alto de la ficha; la lista suma el espacio entre fichas.
  static const double height = 60;

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  late bool _focused = widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final friend = widget.friend;
    final online = friend.isOnline;
    final logoUrl = widget.logoUrl;

    final status = !online
        ? LocaleKeys.friends_status_offline.tr()
        : friend.displayChannelName ?? LocaleKeys.home_friends_no_channel.tr();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvPressDetector(
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onPress: widget.onWatch,
        onLongPress: widget.onDelete,
        onUp: widget.onKeyUp,
        onDown: widget.onKeyDown,
        onRight: TvPressDetector.consuming(widget.onKeyRightAcross),
        child: GestureDetector(
          onTap: widget.onWatch,
          onLongPress: widget.onDelete,
          child: MoaiGlass(
            borderRadius: 14,
            elevated: false,
            solid: true,
            focused: _focused,
            tint: widget.withMe ? scheme.primary : null,
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            child: Row(
              children: [
                FriendAvatar(
                  userCode: friend.userCode,
                  online: online,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: online
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (widget.withMe) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1,
                              ),
                              decoration: moaiGlassChipDecoration(
                                scheme,
                                highlighted: true,
                              ),
                              child: Text(
                                LocaleKeys.home_friends_with_you.tr(),
                                style: MoaiText.body(
                                  context,
                                  color: scheme.onSurface,
                                  fontSize: MoaiText.sizeCaption,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // El logo del canal: lo que se va a ver con OK.
                if (online && logoUrl != null && logoUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TvListCardLeadingLogo(
                      logoUrl: logoUrl,
                      width: 48,
                      height: 34,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
