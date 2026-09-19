import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
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

/// Administración de fuentes de canales (plugins `.dex` por URL).
class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  static const bool _showMyPlugs = true;

  final TextEditingController _urlController =
      TextEditingController(text: 'https://');
  final FocusNode _backFocus = FocusNode(debugLabel: 'sources_back');
  final FocusNode _urlFocus = FocusNode(debugLabel: 'sources_url');
  final FocusNode _installFocus = FocusNode(debugLabel: 'sources_install');
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _tileFocuses = [];
  final List<FocusNode> _presetFocuses = [];
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'sources_empty');

  static const String _arUrl =
      'https://raw.githubusercontent.com/dariomadeira/moaiplug_ar/refs/heads/main/manifest.json';

  static const List<_PresetPlugin> _presetPlugins = [
    _PresetPlugin(
      name: 'Argentina (AR)',
      description: 'moaiplug_ar',
      url: _arUrl,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _urlFocus.addListener(_onUrlFocusChange);
    if (_showMyPlugs) {
      for (var i = 0; i < _presetPlugins.length; i++) {
        _presetFocuses.add(FocusNode(debugLabel: 'sources_preset_$i'));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _urlFocus.requestFocus();
    });
  }

  void _onUrlFocusChange() {
    if (_urlFocus.hasFocus && _urlController.text.trim().isEmpty) {
      setState(() {
        _urlController.text = 'https://';
        _urlController.selection =
            TextSelection.collapsed(offset: _urlController.text.length);
      });
    }
  }

  @override
  void dispose() {
    _urlFocus.removeListener(_onUrlFocusChange);
    _urlController.dispose();
    _backFocus.dispose();
    _urlFocus.dispose();
    _installFocus.dispose();
    _scrollController.dispose();
    _emptyFocusNode.dispose();
    for (final node in _tileFocuses) {
      node.dispose();
    }
    for (final node in _presetFocuses) {
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

  void _resyncFocus(int sourceCount) {
    while (_tileFocuses.length < sourceCount * 2) {
      _tileFocuses.add(FocusNode(debugLabel: 'sources_tile'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final controller = context.watch<PluginHostController>();
    _resyncFocus(controller.sources.length);

    final totalSources = controller.sources.length;
    final totalChannels = controller.sources.fold<int>(
      0,
      (sum, source) => sum + source.canales.length,
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, scheme, totalChannels),
                const SizedBox(height: 18),
                _inputBar(context, scheme, controller),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: scheme.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.error!,
                              style: MoaiText.body(
                                context,
                                color: scheme.onErrorContainer,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: _showMyPlugs
                      ? _buildTwoColumnLayout(context, scheme, controller, totalSources)
                      : _buildSingleColumnLayout(context, scheme, controller, totalSources),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
    int totalSources,
  ) {
    return controller.loading
        ? Center(
            child: CircularProgressIndicator(
              color: scheme.primary,
              strokeWidth: 3,
            ),
          )
        : totalSources == 0
            ? TvEmptyStateCard(
                focusNode: _emptyFocusNode,
                icon: Icons.extension_off_outlined,
                message: 'sources_empty'.tr(),
                onFocusUp: () => _installFocus.requestFocus(),
              )
            : Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: totalSources,
                  itemBuilder: (context, i) {
                    final source = controller.sources[i];
                    final updateNode = _tileFocuses[i * 2];
                    final removeNode = _tileFocuses[i * 2 + 1];
                    final isFirst = i == 0;
                    final isLast = i == totalSources - 1;

                    return _SourceTile(
                      key: ValueKey(source.id),
                      source: source,
                      updateFocus: updateNode,
                      removeFocus: removeNode,
                      onUpdateKeyUp: () {
                        if (isFirst) {
                          _urlFocus.requestFocus();
                        } else {
                          _tileFocuses[(i - 1) * 2].requestFocus();
                        }
                      },
                      onUpdateKeyDown: () {
                        if (!isLast) {
                          _tileFocuses[(i + 1) * 2].requestFocus();
                        }
                      },
                      onRemoveKeyUp: () {
                        if (isFirst) {
                          _installFocus.requestFocus();
                        } else {
                          _tileFocuses[(i - 1) * 2 + 1].requestFocus();
                        }
                      },
                      onRemoveKeyDown: () {
                        if (!isLast) {
                          _tileFocuses[(i + 1) * 2 + 1].requestFocus();
                        }
                      },
                      onUpdate: () => controller.updateSource(source.sourceUrl),
                      onRemove: () => controller.removePlugin(source.id),
                    );
                  },
                ),
              );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
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
                padding: const EdgeInsets.only(bottom: 10),
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
                            icon: Icons.extension_off_outlined,
                            message: 'sources_empty'.tr(),
                            onFocusUp: () => _urlFocus.requestFocus(),
                            onFocusRight: _presetFocuses.isNotEmpty
                                ? () => _presetFocuses.first.requestFocus()
                                : null,
                          )
                        : Scrollbar(
                            controller: _scrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: totalSources,
                              itemBuilder: (context, i) {
                                final source = controller.sources[i];
                                final updateNode = _tileFocuses[i * 2];
                                final removeNode = _tileFocuses[i * 2 + 1];
                                final isFirst = i == 0;
                                final isLast = i == totalSources - 1;

                                return _SourceTile(
                                  key: ValueKey(source.id),
                                  source: source,
                                  updateFocus: updateNode,
                                  removeFocus: removeNode,
                                  onUpdateKeyUp: () {
                                    if (isFirst) {
                                      _urlFocus.requestFocus();
                                    } else {
                                      _tileFocuses[(i - 1) * 2].requestFocus();
                                    }
                                  },
                                  onUpdateKeyDown: () {
                                    if (!isLast) {
                                      _tileFocuses[(i + 1) * 2].requestFocus();
                                    }
                                  },
                                  onRemoveKeyUp: () {
                                    if (isFirst) {
                                      _installFocus.requestFocus();
                                    } else {
                                      _tileFocuses[(i - 1) * 2 + 1].requestFocus();
                                    }
                                  },
                                  onRemoveKeyDown: () {
                                    if (!isLast) {
                                      _tileFocuses[(i + 1) * 2 + 1].requestFocus();
                                    }
                                  },
                                  onRemoveKeyRight: _presetFocuses.isNotEmpty
                                      ? () {
                                          final targetIndex =
                                              i.clamp(0, _presetFocuses.length - 1);
                                          _presetFocuses[targetIndex].requestFocus();
                                        }
                                      : null,
                                  onUpdate: () =>
                                      controller.updateSource(source.sourceUrl),
                                  onRemove: () =>
                                      controller.removePlugin(source.id),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'sources_preset_header'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _presetPlugins.length,
                  itemBuilder: (context, i) {
                    final preset = _presetPlugins[i];
                    final isInstalled = controller.sources.any(
                      (s) => s.sourceUrl == preset.url,
                    );
                    return _PresetTile(
                      key: ValueKey(preset.url),
                      preset: preset,
                      focusNode: _presetFocuses[i],
                      isInstalled: isInstalled,
                      onInstall: () => _install(preset.url),
                      onKeyLeft: () {
                        if (totalSources > 0) {
                          final targetIndex =
                              (i * 2 + 1).clamp(0, _tileFocuses.length - 1);
                          _tileFocuses[targetIndex].requestFocus();
                        } else {
                          _emptyFocusNode.requestFocus();
                        }
                      },
                      onKeyUp: () {
                        if (i == 0) {
                          _installFocus.requestFocus();
                        } else {
                          _presetFocuses[i - 1].requestFocus();
                        }
                      },
                      onKeyDown: () {
                        if (i < _presetPlugins.length - 1) {
                          _presetFocuses[i + 1].requestFocus();
                        }
                      },
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

  Widget _header(BuildContext context, ColorScheme scheme, int totalChannels) {
    return Row(
      children: [
        _BackButton(
          focusNode: _backFocus,
          onPressed: () => Navigator.of(context).pop(),
          onFocusRight: () => _urlFocus.requestFocus(),
          onFocusDown: () => _urlFocus.requestFocus(),
        ),
        const SizedBox(width: 14),
        Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Symbols.extension,
              color: scheme.onPrimaryContainer,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'sources_title'.tr(),
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'sources_subtitle'.tr(),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (totalChannels > 0) ...[
          const SizedBox(width: 12),
          Material(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _formatChannelsCount(totalChannels),
                style: MoaiText.body(
                  context,
                  color: scheme.onTertiaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _inputBar(
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
            leadingIcon: Icons.link_rounded,
            onSubmitted: (val) => _install(val),
            onFocusLeft: () => _backFocus.requestFocus(),
            onFocusRight: () => _installFocus.requestFocus(),
            onFocusUp: () => _backFocus.requestFocus(),
            onFocusDown: hasSources
                ? () => _tileFocuses.first.requestFocus()
                : () => _emptyFocusNode.requestFocus(),
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _installFocus,
          label: 'sources_install'.tr(),
          icon: Symbols.install_desktop,
          height: 60,
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
          onArrowUp: () => _backFocus.requestFocus(),
          onArrowDown: hasSources
              ? () => _tileFocuses.first.requestFocus()
              : () => _emptyFocusNode.requestFocus(),
        ),
      ],
    );
  }
}

class _BackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback? onFocusRight;
  final VoidCallback? onFocusDown;

  const _BackButton({
    required this.focusNode,
    required this.onPressed,
    this.onFocusRight,
    this.onFocusDown,
  });

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isFocused = false;

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
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final fg = _isFocused ? scheme.onPrimary : scheme.onSurface;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight && widget.onFocusRight != null) {
          widget.onFocusRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onFocusDown != null) {
          widget.onFocusDown!();
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
        scale: _isFocused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                Icons.arrow_back_rounded,
                color: fg,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatefulWidget {
  final PluginSource source;
  final FocusNode updateFocus;
  final FocusNode removeFocus;
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
    if (mounted) {
      setState(() {});
      if (widget.updateFocus.hasFocus || widget.removeFocus.hasFocus) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = widget.updateFocus.hasFocus || widget.removeFocus.hasFocus;

    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Material(
              color: iconBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Symbols.electrical_services,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.source.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v${widget.source.version} · '
                    '${_formatChannelsCount(widget.source.canales.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: descColor,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _IconButtonAction(
              focusNode: widget.updateFocus,
              tooltip: 'sources_update'.tr(),
              icon: Icons.sync_rounded,
              onPressed: widget.onUpdate,
              parentFocused: isFocused,
              onKeyRight: () => widget.removeFocus.requestFocus(),
              onKeyUp: widget.onUpdateKeyUp,
              onKeyDown: widget.onUpdateKeyDown,
            ),
            const SizedBox(width: 8),
            _IconButtonAction(
              focusNode: widget.removeFocus,
              tooltip: 'sources_remove'.tr(),
              icon: Icons.delete_outline_rounded,
              onPressed: widget.onRemove,
              parentFocused: isFocused,
              onKeyLeft: () => widget.updateFocus.requestFocus(),
              onKeyRight: widget.onRemoveKeyRight,
              onKeyUp: widget.onRemoveKeyUp,
              onKeyDown: widget.onRemoveKeyDown,
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatefulWidget {
  final _PresetPlugin preset;
  final FocusNode focusNode;
  final bool isInstalled;
  final VoidCallback onInstall;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  const _PresetTile({
    super.key,
    required this.preset,
    required this.focusNode,
    required this.isInstalled,
    required this.onInstall,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
  });

  @override
  State<_PresetTile> createState() => _PresetTileState();
}

class _PresetTileState extends State<_PresetTile> {
  bool _isFocused = false;

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
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
      if (widget.focusNode.hasFocus) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = _isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onKeyLeft();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            widget.onKeyUp();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            widget.onKeyDown();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            widget.onInstall();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: widget.onInstall,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Symbols.electrical_services,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.preset.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: descColor,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: widget.isInstalled
                      ? (_isFocused
                          ? scheme.onPrimary.withValues(alpha: 0.2)
                          : scheme.tertiaryContainer)
                      : (_isFocused
                          ? scheme.onPrimary
                          : scheme.primary),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isInstalled
                              ? Icons.check_circle_outline_rounded
                              : Symbols.download,
                          size: 16,
                          color: widget.isInstalled
                              ? (_isFocused
                                  ? scheme.onPrimary
                                  : scheme.onTertiaryContainer)
                              : (_isFocused
                                  ? scheme.primary
                                  : scheme.onPrimary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isInstalled
                              ? 'sources_status_installed'.tr()
                              : 'sources_install'.tr(),
                          style: MoaiText.body(
                            context,
                            color: widget.isInstalled
                                ? (_isFocused
                                    ? scheme.onPrimary
                                    : scheme.onTertiaryContainer)
                                : (_isFocused
                                    ? scheme.primary
                                    : scheme.onPrimary),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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
    } else if (widget.parentFocused) {
      bg = scheme.onPrimary.withValues(alpha: 0.18);
      fg = scheme.onPrimary;
    } else {
      bg = scheme.secondaryContainer.withValues(alpha: 0.7);
      fg = scheme.onSecondaryContainer;
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
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: () {
            if (_isFocused) {
              widget.onPressed();
            } else {
              widget.focusNode.requestFocus();
            }
          },
          child: AnimatedScale(
            scale: _isFocused ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}