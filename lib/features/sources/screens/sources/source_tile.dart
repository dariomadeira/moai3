part of '../sources_screen.dart';

class _SourceTile extends StatefulWidget {
  final PluginSource source;
  final FocusNode updateFocus;
  final FocusNode removeFocus;
  final VoidCallback? onUpdateKeyLeft;
  final VoidCallback onUpdateKeyUp;
  final VoidCallback onUpdateKeyDown;
  final VoidCallback onRemoveKeyUp;
  final VoidCallback onRemoveKeyDown;
  final VoidCallback? onRemoveKeyRight;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const _SourceTile({
    super.key,
    required this.source,
    required this.updateFocus,
    required this.removeFocus,
    this.onUpdateKeyLeft,
    required this.onUpdateKeyUp,
    required this.onUpdateKeyDown,
    required this.onRemoveKeyUp,
    required this.onRemoveKeyDown,
    this.onRemoveKeyRight,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<_SourceTile> {
  String? _availableVersion;

  @override
  void initState() {
    super.initState();
    widget.updateFocus.addListener(_onFocus);
    widget.removeFocus.addListener(_onFocus);
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final info = await PluginUpdateService.checkSingleSource(widget.source);
    if (info != null && mounted) {
      setState(() {
        _availableVersion = info.remoteVersion;
      });
    }
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
    final scheme = context.scheme;
    final isFocused =
        widget.updateFocus.hasFocus || widget.removeFocus.hasFocus;

    return TvInfoTile(
      isFocused: isFocused,
      minHeight: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      label: widget.source.nombre,
      description: 'v${widget.source.version} · ${_formatChannelsCount(widget.source.canales.length)}',
      icon: MoaiIcons.plugin,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_availableVersion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: isFocused
                    ? scheme.onPrimary.withValues(alpha: 0.22)
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                LocaleKeys.sources_version_available.tr(
                  namedArgs: {'version': _availableVersion!},
                ),
                style: MoaiText.body(
                  context,
                  color: isFocused
                      ? scheme.onPrimary
                      : scheme.onPrimaryContainer,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          TvIconActionButton(
            focusNode: widget.updateFocus,
            tooltip: LocaleKeys.common_update.tr(),
            icon: _availableVersion != null
                ? MoaiIcons.pluginUpdate
                : MoaiIcons.sync,
            onPressed: () {
              widget.onUpdate();
              setState(() => _availableVersion = null);
            },
            parentFocused: isFocused,
            onKeyLeft: widget.onUpdateKeyLeft,
            onKeyRight: () => widget.removeFocus.requestFocus(),
            onKeyUp: widget.onUpdateKeyUp,
            onKeyDown: widget.onUpdateKeyDown,
          ),
          const SizedBox(width: 8),
          TvIconActionButton(
            focusNode: widget.removeFocus,
            tooltip: LocaleKeys.sources_remove.tr(),
            icon: MoaiIcons.delete,
            onPressed: widget.onRemove,
            parentFocused: isFocused,
            onKeyLeft: () => widget.updateFocus.requestFocus(),
            onKeyRight: widget.onRemoveKeyRight,
            onKeyUp: widget.onRemoveKeyUp,
            onKeyDown: widget.onRemoveKeyDown,
          ),
        ],
      ),
    );
  }
}
