part of '../general_plugins_screen.dart';

class _InstalledPluginTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final FocusNode updateFocus;
  final FocusNode removeFocus;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;
  final VoidCallback? onUpdateKeyLeft;
  final VoidCallback onUpdateKeyUp;
  final VoidCallback onRemoveKeyUp;
  final VoidCallback? onRemoveKeyRight;
  final double? minHeight;

  const _InstalledPluginTile({
    required this.title,
    required this.subtitle,
    required this.updateFocus,
    required this.removeFocus,
    required this.onUpdate,
    required this.onRemove,
    this.onUpdateKeyLeft,
    required this.onUpdateKeyUp,
    required this.onRemoveKeyUp,
    this.onRemoveKeyRight,
    this.minHeight,
  });

  @override
  State<_InstalledPluginTile> createState() => _InstalledPluginTileState();
}

class _InstalledPluginTileState extends State<_InstalledPluginTile> {
  @override
  void initState() {
    super.initState();
    widget.updateFocus.addListener(_onFocus);
    widget.removeFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.updateFocus.removeListener(_onFocus);
    widget.removeFocus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.updateFocus.hasFocus || widget.removeFocus.hasFocus;

    return TvInfoTile(
      isFocused: isFocused,
      minHeight: widget.minHeight ?? 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      label: widget.title,
      description: widget.subtitle,
      icon: MoaiIcons.tvViewerPillPlugin,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TvIconActionButton(
            focusNode: widget.updateFocus,
            tooltip: LocaleKeys.plugins_reinstall_tooltip.tr(),
            icon: MoaiIcons.sync,
            onPressed: widget.onUpdate,
            parentFocused: isFocused,
            onKeyLeft: widget.onUpdateKeyLeft,
            onKeyRight: () => widget.removeFocus.requestFocus(),
            onKeyUp: widget.onUpdateKeyUp,
          ),
          const SizedBox(width: 8),
          TvIconActionButton(
            focusNode: widget.removeFocus,
            tooltip: LocaleKeys.plugins_uninstall_tooltip.tr(),
            icon: MoaiIcons.delete,
            onPressed: widget.onRemove,
            parentFocused: isFocused,
            onKeyLeft: () => widget.updateFocus.requestFocus(),
            onKeyRight: widget.onRemoveKeyRight,
            onKeyUp: widget.onRemoveKeyUp,
          ),
        ],
      ),
    );
  }
}
