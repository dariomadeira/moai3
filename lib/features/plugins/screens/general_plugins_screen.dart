import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/buttons/tv_install_pill.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/buttons/tv_icon_action_button.dart';

class _GeneralPluginItem {
  final String id;
  final String name;
  final String description;
  final bool isArcade;

  const _GeneralPluginItem({
    required this.id,
    required this.name,
    required this.description,
    this.isArcade = false,
  });
}

/// Pantalla de gestión de Plugins Generales para Android TV (idéntica a la estructura de SourcesScreen).
class GeneralPluginsScreen extends StatefulWidget {
  const GeneralPluginsScreen({super.key});

  @override
  State<GeneralPluginsScreen> createState() => _GeneralPluginsScreenState();
}

class _GeneralPluginsScreenState extends State<GeneralPluginsScreen> {
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'general_plugins_back');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'general_plugins_empty');

  final GlobalKey<TvWindowedListState<_GeneralPluginItem>> _availableListKey =
      GlobalKey<TvWindowedListState<_GeneralPluginItem>>();

  int _selectedAvailableIndex = 0;

  // Focus nodes para plugin instalado (update & remove)
  final FocusNode _installedUpdateFocus = FocusNode(debugLabel: 'arcade_update_focus');
  final FocusNode _installedRemoveFocus = FocusNode(debugLabel: 'arcade_remove_focus');

  List<_GeneralPluginItem> get _availablePlugins => [
        _GeneralPluginItem(
          id: 'arcade_fbneo',
          name: LocaleKeys.plugins_arcade_available_name.tr(),
          description: LocaleKeys.plugins_arcade_available_desc.tr(),
          isArcade: true,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _arcadePlugin.addListener(_onPluginUpdated);
    unawaited(_arcadePlugin.refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_arcadePlugin.isInstalled) {
          _installedRemoveFocus.requestFocus();
        } else {
          _focusAvailableList();
        }
      }
    });
  }

  void _onPluginUpdated() {
    if (mounted) setState(() {});
  }

  void _focusAvailableList() {
    if (_availablePlugins.isEmpty) return;
    final index = _selectedAvailableIndex.clamp(0, _availablePlugins.length - 1);
    _availableListKey.currentState?.ensureVisible(index);
  }

  @override
  void dispose() {
    _arcadePlugin.removeListener(_onPluginUpdated);
    _backFocusNode.dispose();
    _emptyFocusNode.dispose();
    _installedUpdateFocus.dispose();
    _installedRemoveFocus.dispose();
    super.dispose();
  }

  Future<void> _uninstallArcade() async {
    await _arcadePlugin.uninstallPlugin();
    if (mounted) _focusAvailableList();
  }

  Future<void> _installArcade() async {
    if (_arcadePlugin.isDownloading || _arcadePlugin.isInstalled) return;
    await _arcadePlugin.installPlugin();
    if (mounted && _arcadePlugin.isInstalled) {
      _installedRemoveFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isInstalled = _arcadePlugin.isInstalled;
    final totalInstalledCount = isInstalled ? 1 : 0;

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
                child: Image.asset(
                  'assets/images/fondo.png',
                  fit: BoxFit.cover,
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
                        children: [
                          const SizedBox(height: 9),
                          TvBackPill(
                            focusNode: _backFocusNode,
                            onKeyRight: () {
                              if (isInstalled) {
                                _installedRemoveFocus.requestFocus();
                              } else {
                                _focusAvailableList();
                              }
                            },
                            onKeyDown: () {
                              if (isInstalled) {
                                _installedRemoveFocus.requestFocus();
                              } else {
                                _focusAvailableList();
                              }
                            },
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
                          titles: [LocaleKeys.settings_general_plugins_title.tr()],
                          icons: const [MoaiIcons.tvViewerPillPlugin],
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
                                      LocaleKeys.settings_general_plugins_title.tr(),
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
                                    MoaiIcons.tvViewerPillPlugin,
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
                                    children: [
                                      Expanded(
                                        child: TvPanelHeader(
                                          title: LocaleKeys.plugins_admin_title.tr(),
                                          subtitle: LocaleKeys.plugins_admin_subtitle.tr(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (totalInstalledCount > 0) ...[
                                        const SizedBox(width: 12),
                                        TvMetaPill(
                                          icon: MoaiIcons.tvViewerPillPlugin,
                                          label: LocaleKeys.plugins_count_single
                                              .tr(namedArgs: {'count': '1'}),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                  Expanded(
                                    child: _buildTwoColumnLayout(
                                      context,
                                      scheme,
                                      isInstalled,
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

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    bool isInstalled,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Plugins Instalados
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.plugins_installed_column_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: !isInstalled
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.extensionOffOutlined,
                        message: LocaleKeys.plugins_empty_installed_msg.tr(),
                        onFocusLeft: _backFocusNode.requestFocus,
                        onFocusUp: _backFocusNode.requestFocus,
                        onFocusRight: _focusAvailableList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 5;
                          final availableH = constraints.maxHeight;
                          final itemExtent =
                              (availableH / windowSize).floorToDouble();
                          final tileMinHeight =
                              (itemExtent - 6.0).clamp(0.0, double.infinity);

                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: _InstalledPluginTile(
                                title: LocaleKeys.plugins_arcade_name.tr(),
                                subtitle: LocaleKeys.plugins_arcade_desc.tr(
                                  namedArgs: {'abi': ArcadePluginService.getDeviceAbi()},
                                ),
                                minHeight: tileMinHeight,
                                updateFocus: _installedUpdateFocus,
                                removeFocus: _installedRemoveFocus,
                                onUpdate: _installArcade,
                                onRemove: _uninstallArcade,
                                onUpdateKeyLeft: _backFocusNode.requestFocus,
                                onUpdateKeyUp: _backFocusNode.requestFocus,
                                onRemoveKeyUp: _backFocusNode.requestFocus,
                                onRemoveKeyRight: _focusAvailableList,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Columna Derecha: Plugins Disponibles (Windowed List con mock de 8)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.plugins_available_column_title.tr(),
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
                    const windowSize = 5;
                    final availableH = constraints.maxHeight;
                    final itemExtent = (availableH / windowSize).floorToDouble();

                    return SizedBox(
                      height: availableH,
                      child: TvWindowedList<_GeneralPluginItem>(
                        key: _availableListKey,
                        items: _availablePlugins,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedAvailableIndex,
                        focusOnMount: false,
                        onFocusedGlobalIndex: (idx) {
                          _selectedAvailableIndex = idx;
                        },
                        onFocusUpFromFirst: _backFocusNode.requestFocus,
                        itemBuilder: (
                          context,
                          item,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) {
                          final isItemInstalled = item.isArcade && isInstalled;
                          final isItemDownloading =
                              item.isArcade && _arcadePlugin.isDownloading;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: TvTile(
                              focusNode: focusNode,
                              minHeight: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              label: item.name,
                              description: item.description,
                              icon: MoaiIcons.tvViewerPillPlugin,
                              onPressed: () {
                                if (item.isArcade) {
                                  if (!isItemInstalled && !isItemDownloading) {
                                    _installArcade();
                                  }
                                }
                              },
                              onKeyLeft: () {
                                if (isInstalled) {
                                  _installedRemoveFocus.requestFocus();
                                } else {
                                  _emptyFocusNode.requestFocus();
                                }
                              },
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                              trailingBuilder: (context, isFocused) =>
                                  TvInstallPill(
                                isInstalled: isItemInstalled,
                                isFocused: isFocused,
                                downloadProgress: isItemDownloading
                                    ? _arcadePlugin.downloadProgress
                                    : null,
                                installLabel: LocaleKeys.common_install.tr(),
                                installedLabel: LocaleKeys.common_installed.tr(),
                                onPressed: () {
                                  if (item.isArcade) {
                                    if (!isItemInstalled && !isItemDownloading) {
                                      _installArcade();
                                    }
                                  }
                                },
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
            icon: MoaiIcons.syncRounded,
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
            icon: MoaiIcons.deleteOutlineRounded,
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
