import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/buttons/tv_install_pill.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
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
import 'package:moai3/widgets/buttons/tv_icon_action_button.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:moai3/widgets/tv_common/moai_background_image.dart';

part 'sources/sources_layout.dart';
part 'sources/source_tile.dart';

String _formatChannelsCount(int count) {
  final label = count == 1
      ? LocaleKeys.sources_channel_singular.tr()
      : LocaleKeys.sources_channel_plural.tr();
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
          name: LocaleKeys.sources_preset_ar_name.tr(),
          description: LocaleKeys.sources_preset_ar_desc.tr(),
          url: _arUrl,
        ),
        _PresetPlugin(
          name: LocaleKeys.sources_preset_daddylive_name.tr(),
          description: LocaleKeys.sources_preset_daddylive_desc.tr(),
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
    _presetsListKey.currentState?.ensureVisible(index);
  }

  void _resyncFocus(int sourceCount) {
    final needed = sourceCount * 2;
    while (_tileFocuses.length < needed) {
      _tileFocuses.add(
        FocusNode(debugLabel: 'sources_tile_${_tileFocuses.length}'),
      );
    }
    if (_tileFocuses.length > needed) {
      for (final node in _tileFocuses.sublist(needed)) {
        node.dispose();
      }
      _tileFocuses.removeRange(needed, _tileFocuses.length);
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
            const Positioned.fill(
              child: IgnorePointer(
                child: MoaiBackgroundImage(MoaiBackground.screen),
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
                        children: [
                          const SizedBox(height: 9),
                          TvBackPill(
                            focusNode: _backFocusNode,
                            onKeyRight: _urlFocus.requestFocus,
                            onKeyDown: hasSources
                                ? () => _tileFocuses.first.requestFocus()
                                : _emptyFocusNode.requestFocus,
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
                          titles: [LocaleKeys.settings_general_sources.tr()],
                          icons: const [MoaiIcons.extension],
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
                                      LocaleKeys.settings_general_sources.tr(),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: MoaiText.display(
                                        context,
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Icon(
                                    MoaiIcons.extension,
                                    size: MoaiIconSizes.md,
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
                                    children: [
                                      Expanded(
                                        child: TvPanelHeader(
                                          title: LocaleKeys.sources_title.tr(),
                                          subtitle: LocaleKeys.sources_subtitle.tr(),
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
                                              MoaiIcons.error,
                                              color: scheme.onErrorContainer,
                                              size: MoaiIconSizes.md,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                controller.error!.tr(
                                                  namedArgs:
                                                      controller.errorNamedArgs,
                                                ),
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
}
