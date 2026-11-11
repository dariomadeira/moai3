part of '../tv_friends_dialog.dart';

/// Un usuario con la misma ficha que los amigos: avatar con el punto de
/// estado, el nombre, [subtitle] y su código a la derecha. Lo usan las
/// solicitudes recibidas ("Quiere ser tu amigo") y los resultados de buscar.
///
/// OK: [onAccept]. OK mantenido: [onReject] (si hay; en solicitudes pide
/// confirmar y rechaza). Las repeticiones de un OK que ya venía apretado no
/// hacen nada ([TvPressDetector]).
class _RequestTile extends StatefulWidget {
  final FriendInfo request;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyLeftAcross;
  final String subtitle;
  final VoidCallback onAccept;
  final VoidCallback? onReject;

  const _RequestTile({
    super.key,
    required this.request,
    required this.focusNode,
    required this.isLoading,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyLeftAcross,
    required this.subtitle,
    required this.onAccept,
    this.onReject,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  late bool _focused = widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final request = widget.request;
    final busy = widget.isLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvPressDetector(
        focusNode: widget.focusNode,
        onFocusChange: (f) => setState(() => _focused = f),
        onPress: busy ? null : widget.onAccept,
        onLongPress: busy ? null : widget.onReject,
        onUp: widget.onKeyUp,
        onDown: widget.onKeyDown,
        onLeft: TvPressDetector.consuming(widget.onKeyLeftAcross),
        child: GestureDetector(
          onTap: busy ? null : widget.onAccept,
          onLongPress: busy ? null : widget.onReject,
          child: MoaiGlass(
            borderRadius: 14,
            elevated: false,
            solid: true,
            focused: _focused,
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            child: Row(
              children: [
                FriendAvatar(
                  userCode: request.userCode,
                  online: request.isOnline,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy && _focused)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  // Su código: la misma pastilla de cristal que el código en
                  // Ajustes › Miremos juntos.
                  TvValueChip(text: request.userCode, isFocused: _focused),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
