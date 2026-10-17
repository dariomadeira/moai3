import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/buttons/tv_install_pill.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

String _formatChannelsCount(int count) {
  final label = count == 1
      ? 'sources_channel_singular'.tr()
      : 'sources_channel_plural'.tr();
  return '$count $label';
}

class _PresetPlugin {
  final String name;
  final String description;
  final String url;

  const _PresetPlugin({
    required this.name,
    required this.description,
    required this.url,
  });
}

/// Pantalla del Administrador de Extensiones con layout de 2 columnas dentro del panel TV.
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://',
  );
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'sources_rail_back');
  final FocusNode _urlFocus = FocusNode(debugLabel: 'sources_url');
  final FocusNode _installFocus = FocusNode(debugLabel: 'sources_install');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'sources_empty');
  final GlobalKey<TvWindowedListState<PluginSource>> _installedListKey =
      GlobalKey<TvWindowedListState<PluginSource>>();
  final GlobalKey<TvWindowedListState<_PresetPlugin>> _presetsListKey =
      GlobalKey<TvWindowedListState<_PresetPlugin>>();

  int _selectedInstalledIndex = 0;
  int _selectedPresetIndex = 0;

  final List<FocusNode> _tileFocuses = [];

  static const String _arUrl =
      'https://raw.githubusercontent.com/dariomadeira/moaiplug_ar/refs/heads/main/manifest.json';
  static const String _daddyliveUrl =
      'https://raw.githubusercontent.com/dariomadeira/moaiplug_daddylive/refs/heads/main/manifest.json';

  static List<_PresetPlugin> get _presetPlugins => [
        _PresetPlugin(
          name: 'sources_preset_ar_name'.tr(),
          description: 'sources_preset_ar_desc'.tr(),
          url: _arUrl,
        ),
        _PresetPlugin(
          name: 'sources_preset_daddylive_name'.tr(),
          description: 'sources_preset_daddylive_desc'.tr(),
          url: _daddyliveUrl,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(_onUrlFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _urlFocus.requestFocus();
      }
    });
  }

  void _onUrlFocusChange() {
    if (_urlFocus.hasFocus && _urlController.text.trim().isEmpty) {
      setState(() {
        _urlController.text = 'https://';
        _urlController.selection = TextSelection.collapsed(
          offset: _urlController.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _urlFocus.removeListener(_onUrlFocusChange);
    _urlController.dispose();
    _backFocusNode.dispose();
    _urlFocus.dispose();
    _installFocus.dispose();
    _emptyFocusNode.dispose();
    for (final node in _tileFocuses) {
      node.dispose();
    }
    super.dispose();
  }

  void _install([String? customUrl]) {
    var url = (customUrl ?? _urlController.text).trim();
    if (url.isEmpty || url == 'https://' || url == 'http://') return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    context.read<PluginHostController>().install(url);
  }

  void _focusPresetList() {
    if (_presetPlugins.isEmpty) return;
    final index = _selectedPresetIndex.clamp(0, _presetPlugins.length - 1);
    _presetsListKey.currentState?.ensureVisible(index, requestFocus: true);
  }

  void _resyncFocus(int sourceCount) {
    while (_tileFocuses.length < sourceCount * 2) {
      _tileFocuses.add(
        FocusNode(debugLabel: 'sources_tile_${_tileFocuses.length}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final controller = context.watch<PluginHostController>();
    final sources = controller.sources;
    _resyncFocus(sources.length);

    final totalSources = sources.length;
    final hasSources = sources.isNotEmpty;
    final totalChannels = sources.fold<int>(
      0,
      (sum, source) => sum + source.canales.length,
    );

    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.brightness == Brightness.dark
                ? [
                    Color.lerp(
                      scheme.surfaceContainerHigh,
                      scheme.primary,
                      0.08,
                    )!,
                    scheme.surfaceContainerLow,
                  ]
                : [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.3,
                  child: Image.asset(
                    'assets/images/fondo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: overlapX,
                  vertical: overlapY,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 9),
                          TvBackPill(
                            focusNode: _backFocusNode,
                            onKeyRight: () => _urlFocus.requestFocus(),
                            onKeyDown: hasSources
                                ? () => _tileFocuses.first.requestFocus()
                                : () => _emptyFocusNode.requestFocus(),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                        child: TvAccordionRowPreview(
                          panelCount: 1,
                          activeIndex: 0,
                          colors: [scheme.surface.withValues(alpha: 0.8)],
                          titles: ['settings_general_sources'.tr()],
                          icons: const [MoaiIcons.extensionOutlined],
                          onPanelTap: (_) {},
                          tabBuilder: (index, isExpanded) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 14,
                                top: 14,
                              ),
                              child: Column(
                                children: [
                                  const Spacer(),
                                  RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      'settings_general_sources'.tr(),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: MoaiText.display(
                                        context,
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Icon(
                                    MoaiIcons.extensionOutlined,
                                    size: 20,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          buildExpandedContent: (index, title) {
                            return Container(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: TvPanelHeader(
                                          title: 'sources_title'.tr(),
                                          subtitle: 'sources_subtitle'.tr(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (totalChannels > 0) ...[
                                        const SizedBox(width: 12),
                                        TvMetaPill(
                                          icon: MoaiIcons.tvSourcesTotalChannels,
                                          label: _formatChannelsCount(
                                            totalChannels,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildInputBar(context, scheme, controller),
                                  if (controller.error != null) ...[
                                    const SizedBox(height: 10),
                                    Material(
                                      color: scheme.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              MoaiIcons.errorOutlineRounded,
                                              color: scheme.onErrorContainer,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                controller.error!,
                                                style: MoaiText.body(
                                                  context,
                                                  color:
                                                      scheme.onErrorContainer,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  Expanded(
                                    child: _buildTwoColumnLayout(
                                      context,
                                      scheme,
                                      controller,
                                      sources,
                                      totalSources,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
  ) {
    final hasSources = controller.sources.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TvTextField(
            controller: _urlController,
            focusNode: _urlFocus,
            label: 'sources_url_label'.tr(),
            hint: 'sources_url_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            doneLabel: 'sources_install'.tr(),
            leadingIcon: MoaiIcons.tvSourcesUrlInput,
            onSubmitted: (val) => _install(val),
            onFocusLeft: () => _backFocusNode.requestFocus(),
            onFocusRight: () => _installFocus.requestFocus(),
            onFocusUp: () => _backFocusNode.requestFocus(),
            onFocusDown: hasSources
                ? () => _tileFocuses.first.requestFocus()
                : () => _emptyFocusNode.requestFocus(),
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _installFocus,
          label: 'sources_install'.tr(),
          icon: MoaiIcons.tvSourcesInstallAction,
          height: 60,
          radius: 30,
          variant: TvButtonVariant.tonal,
          onPressed: controller.loading
              ? null
              : () {
                  final text = _urlController.text.trim();
                  if (text.isEmpty || text == 'https://' || text == 'http://') {
                    TvTextField.open(
                      context,
                      title: 'sources_url_label'.tr(),
                      initialValue: text.isEmpty ? 'https://' : text,
                      keyboardType: TvKeyboardType.text,
                      hint: 'sources_url_hint'.tr(),
                      doneLabel: 'sources_install'.tr(),
                    ).then((val) {
                      if (val != null && val.trim().isNotEmpty) {
                        _urlController.text = val;
                        _install(val);
                      }
                    });
                  } else {
                    _install();
                  }
                },
          onLongPress: controller.loading
              ? null
              : () {
                  _urlController.text = _arUrl;
                  _install(_arUrl);
                },
          onArrowLeft: () => _urlFocus.requestFocus(),
          onArrowRight: _focusPresetList,
          onArrowUp: () => _backFocusNode.requestFocus(),
          onArrowDown: hasSources
              ? () => _tileFocuses.first.requestFocus()
              : () => _emptyFocusNode.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
    List<PluginSource> sources,
    int totalSources,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'sources_installed_header'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: controller.loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: scheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : totalSources == 0
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.extensionOffOutlined,
                        message: 'sources_empty'.tr(),
                        onFocusLeft: () => _backFocusNode.requestFocus(),
                        onFocusUp: () => _urlFocus.requestFocus(),
                        onFocusRight: _focusPresetList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 4;
                          final availableH = constraints.maxHeight;
                          final itemExtent = (availableH / windowSize).floorToDouble();

                          return SizedBox(
                            height: availableH,
                            child: TvWindowedList<PluginSource>(
                              key: _installedListKey,
                              items: sources,
                              windowSize: windowSize,
                              itemExtent: itemExtent,
                              showScrollDots: true,
                              initialGlobalIndex: _selectedInstalledIndex,
                              focusOnMount: false,
                              onFocusedGlobalIndex: (idx) {
                                _selectedInstalledIndex = idx;
                              },
                              onFocusUpFromFirst: () =>
                                  _urlFocus.requestFocus(),
                              itemBuilder: (
                                context,
                                source,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                final isFirst = global == 0;
                                final updateNode = _tileFocuses[global * 2];
                                final removeNode = _tileFocuses[global * 2 + 1];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: _SourceTile(
                                    key: ValueKey(source.id),
                                    source: source,
                                    updateFocus: updateNode,
                                    removeFocus: removeNode,
                                    onUpdateKeyLeft: () =>
                                        _backFocusNode.requestFocus(),
                                    onUpdateKeyUp: onKeyUp,
                                    onUpdateKeyDown: onKeyDown,
                                    onRemoveKeyUp: () {
                                      if (isFirst) {
                                        _installFocus.requestFocus();
                                      } else {
                                        onKeyUp();
                                      }
                                    },
                                    onRemoveKeyDown: onKeyDown,
                                    onRemoveKeyRight: _focusPresetList,
                                    onUpdate: () =>
                                        controller.updateSource(source.sourceUrl),
                                    onRemove: () =>
                                        controller.removePlugin(source.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'sources_presets_header'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const windowSize = 4;
                    final availableH = constraints.maxHeight;
                    final itemExtent = (availableH / windowSize).floorToDouble();

                    return SizedBox(
                      height: availableH,
                      child: TvWindowedList<_PresetPlugin>(
                        key: _presetsListKey,
                        items: _presetPlugins,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedPresetIndex,
                        focusOnMount: false,
                        onFocusedGlobalIndex: (idx) {
                          _selectedPresetIndex = idx;
                        },
                        onFocusUpFromFirst: () =>
                            _installFocus.requestFocus(),
                        itemBuilder: (
                          context,
                          preset,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) {
                          final isInstalled = sources.any(
                            (s) => s.sourceUrl == preset.url,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: TvTile(
                              focusNode: focusNode,
                              minHeight: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              label: preset.name,
                              description: preset.description,
                              icon: MoaiIcons.electricalServices,
                              onPressed: () => _install(preset.url),
                              onKeyLeft: () {
                                if (totalSources > 0) {
                                  final targetIndex = (_selectedInstalledIndex * 2 + 1)
                                      .clamp(0, _tileFocuses.length - 1);
                                  _tileFocuses[targetIndex].requestFocus();
                                } else {
                                  _emptyFocusNode.requestFocus();
                                }
                              },
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                              trailingBuilder: (context, isFocused) =>
                                  TvInstallPill(
                                isInstalled: isInstalled,
                                isFocused: isFocused,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
      icon: MoaiIcons.electricalServices,
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
                'sources_version_available'.tr(
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
          _IconButtonAction(
            focusNode: widget.updateFocus,
            tooltip: 'sources_update'.tr(),
            icon: _availableVersion != null
                ? MoaiIcons.systemUpdateRounded
                : MoaiIcons.syncRounded,
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
          _IconButtonAction(
            focusNode: widget.removeFocus,
            tooltip: 'sources_remove'.tr(),
            icon: MoaiIcons.deleteOutlineRounded,
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

class _IconButtonAction extends StatefulWidget {
  final FocusNode focusNode;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool parentFocused;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;

  const _IconButtonAction({
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.parentFocused,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyLeft,
    this.onKeyRight,
  });

  @override
  State<_IconButtonAction> createState() => _IconButtonActionState();
}

class _IconButtonActionState extends State<_IconButtonAction> {
  late bool _isFocused;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final Color bg;
    final Color fg;

    if (_isFocused) {
      if (widget.parentFocused) {
        bg = scheme.onPrimary;
        fg = scheme.primary;
      } else {
        bg = scheme.primary;
        fg = scheme.onPrimary;
      }
    } else {
      if (widget.parentFocused) {
        bg = scheme.onPrimary.withValues(alpha: 0.16);
        fg = scheme.onPrimary;
      } else {
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.5);
        fg = scheme.onSurfaceVariant;
      }
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(widget.icon, color: fg, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}
