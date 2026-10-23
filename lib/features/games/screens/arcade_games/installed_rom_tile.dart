part of '../arcade_games_screen.dart';

class _InstalledRomTile extends StatefulWidget {
  final ArcadeRomItem item;
  final FocusNode deleteFocus;
  final VoidCallback onDeleteKeyUp;
  final VoidCallback onDeleteKeyDown;
  final VoidCallback? onDeleteKeyLeft;
  final VoidCallback? onDeleteKeyRight;
  final VoidCallback onDelete;

  const _InstalledRomTile({
    super.key,
    required this.item,
    required this.deleteFocus,
    required this.onDeleteKeyUp,
    required this.onDeleteKeyDown,
    this.onDeleteKeyLeft,
    this.onDeleteKeyRight,
    required this.onDelete,
  });

  @override
  State<_InstalledRomTile> createState() => _InstalledRomTileState();
}

class _InstalledRomTileState extends State<_InstalledRomTile> {
  @override
  void initState() {
    super.initState();
    widget.deleteFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.deleteFocus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.deleteFocus.hasFocus;

    return TvInfoTile(
      isFocused: isFocused,
      minHeight: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      label: widget.item.name,
      description: '${widget.item.sizeLabel} · ${LocaleKeys.arcade_ready_to_play.tr()}',
      icon: MoaiIcons.arcadeRomCard,
      trailing: TvIconActionButton(
        focusNode: widget.deleteFocus,
        tooltip: LocaleKeys.common_delete.tr(),
        icon: MoaiIcons.arcadeRomDelete,
        onPressed: widget.onDelete,
        parentFocused: isFocused,
        onKeyLeft: widget.onDeleteKeyLeft,
        onKeyRight: widget.onDeleteKeyRight,
        onKeyUp: widget.onDeleteKeyUp,
        onKeyDown: widget.onDeleteKeyDown,
      ),
    );
  }
}
