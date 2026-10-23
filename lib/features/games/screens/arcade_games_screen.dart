import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/buttons/tv_install_pill.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

/// Pantalla para gestionar y descargar ROMs de Arcade.
/// Sigue la misma estructura y diseño de 2 columnas que SourcesScreen.
class ArcadeGamesScreen extends StatefulWidget {
  final ArcadeRomManagerService romManager;

  const ArcadeGamesScreen({
    super.key,
    required this.romManager,
  });

  @override
  State<ArcadeGamesScreen> createState() => _ArcadeGamesScreenState();
}

class _ArcadeGamesScreenState extends State<ArcadeGamesScreen> {
  final TextEditingController _urlController =
      TextEditingController(text: ArcadeRomManagerService.defaultManifestUrl);
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'games_rail_back');
  final FocusNode _urlFocus = FocusNode(debugLabel: 'games_url');
  final FocusNode _refreshFocus = FocusNode(debugLabel: 'games_refresh');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'games_empty');

  final GlobalKey<TvWindowedListState<ArcadeRomItem>> _installedListKey =
      GlobalKey<TvWindowedListState<ArcadeRomItem>>();
  final GlobalKey<TvWindowedListState<ArcadeRomItem>> _catalogListKey =
      GlobalKey<TvWindowedListState<ArcadeRomItem>>();

  int _selectedInstalledIndex = 0;
  int _selectedCatalogIndex = 0;

  final List<FocusNode> _installedDeleteFocuses = [];

  @override
  void initState() {
    super.initState();
    widget.romManager.addListener(_onManagerUpdated);
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshFocus.requestFocus();
    });
  }

  void _onManagerUpdated() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    await widget.romManager.refreshInstalledRoms();
    await widget.romManager.fetchCatalog(_urlController.text.trim());
    _syncFocusNodes();
  }

  void _syncFocusNodes() {
    final installed = widget.romManager.installedRoms;
    while (_installedDeleteFocuses.length < installed.length) {
      _installedDeleteFocuses.add(
        FocusNode(debugLabel: 'installed_del_${_installedDeleteFocuses.length}'),
      );
    }
  }

  void _focusCatalogList() {
    if (widget.romManager.catalog.isEmpty) return;
    final index = _selectedCatalogIndex.clamp(0, widget.romManager.catalog.length - 1);
    _catalogListKey.currentState?.ensureVisible(index);
  }

  @override
  void dispose() {
    widget.romManager.removeListener(_onManagerUpdated);
    _urlController.dispose();
    _backFocusNode.dispose();
    _urlFocus.dispose();
    _refreshFocus.dispose();
    _emptyFocusNode.dispose();
    for (final f in _installedDeleteFocuses) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _deleteRom(ArcadeRomItem item) async {
    await widget.romManager.deleteRom(item.filename);
    _syncFocusNodes();
  }

  @override
  Widget build(BuildContext context) {
    _syncFocusNodes();
    final scheme = context.scheme;
    final installed = widget.romManager.installedRoms;
    final catalog = widget.romManager.catalog;
    final installedCount = installed.length;
    final hasInstalled = installed.isNotEmpty;

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
                            onKeyRight: _urlFocus.requestFocus,
                            onKeyDown: hasInstalled
                                ? () => _installedDeleteFocuses.first.requestFocus()
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
                          titles: ['arcade_action_select_game'.tr()],
                          icons: const [MoaiIcons.arcadeRomItem],
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
                                      'arcade_action_select_game'.tr(),
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
                                    MoaiIcons.arcadeRomItem,
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
                                          title: 'arcade_games_title'.tr(),
                                          subtitle: 'arcade_games_subtitle'.tr(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      if (installedCount > 0) ...[
                                        const SizedBox(width: 12),
                                        TvMetaPill(
                                          icon: MoaiIcons.arcadeRomInstalledBadge,
                                          label: installedCount == 1
                                              ? 'arcade_installed_count_single'
                                                  .tr(namedArgs: {'count': '1'})
                                              : 'arcade_installed_count_plural'
                                                  .tr(namedArgs: {
                                                  'count': installedCount.toString(),
                                                }),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  _buildUrlRow(context, scheme, hasInstalled),
                                  if (widget.romManager.errorMessage != null) ...[
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
                                                widget.romManager.errorMessage!.tr(),
                                                style: MoaiText.body(
                                                  context,
                                                  color: scheme.onErrorContainer,
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
                                      installed,
                                      catalog,
                                      hasInstalled,
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

  Widget _buildUrlRow(
    BuildContext context,
    ColorScheme scheme,
    bool hasInstalled,
  ) {
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _urlController,
            focusNode: _urlFocus,
            label: 'arcade_input_url_label'.tr(),
            hint: 'arcade_input_url_hint'.tr(),
            doneLabel: 'arcade_input_url_done'.tr(),
            leadingIcon: MoaiIcons.tvSourcesUrlInput,
            onSubmitted: (val) => _loadData(),
            onFocusLeft: _backFocusNode.requestFocus,
            onFocusRight: _refreshFocus.requestFocus,
            onFocusUp: _backFocusNode.requestFocus,
            onFocusDown: hasInstalled
                ? () => _installedDeleteFocuses.first.requestFocus()
                : _emptyFocusNode.requestFocus,
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _refreshFocus,
          label: 'arcade_btn_refresh'.tr(),
          icon: MoaiIcons.arcadeCatalogRefresh,
          height: 60,
          radius: 30,
          variant: TvButtonVariant.tonal,
          onPressed: widget.romManager.isLoading ? null : _loadData,
          onArrowLeft: _urlFocus.requestFocus,
          onArrowRight: _focusCatalogList,
          onArrowUp: _backFocusNode.requestFocus,
          onArrowDown: hasInstalled
              ? () => _installedDeleteFocuses.first.requestFocus()
              : _emptyFocusNode.requestFocus,
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    List<ArcadeRomItem> installed,
    List<ArcadeRomItem> catalog,
    bool hasInstalled,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna 1: Juegos Instalados
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'arcade_installed_column_title'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: !hasInstalled
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.arcadeRomItem,
                        message: 'arcade_empty_installed_msg'.tr(),
                        onFocusLeft: _backFocusNode.requestFocus,
                        onFocusUp: _urlFocus.requestFocus,
                        onFocusRight: _focusCatalogList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 4;
                          final availableH = constraints.maxHeight;
                          final itemExtent =
                              (availableH / windowSize).floorToDouble();

                          return SizedBox(
                            height: availableH,
                            child: TvWindowedList<ArcadeRomItem>(
                              key: _installedListKey,
                              items: installed,
                              windowSize: windowSize,
                              itemExtent: itemExtent,
                              showScrollDots: true,
                              initialGlobalIndex: _selectedInstalledIndex,
                              focusOnMount: false,
                              onFocusedGlobalIndex: (idx) {
                                _selectedInstalledIndex = idx;
                              },
                              onFocusUpFromFirst: _urlFocus.requestFocus,
                              itemBuilder: (
                                context,
                                item,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                final isFirst = global == 0;
                                final deleteNode = _installedDeleteFocuses[global];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: _InstalledRomTile(
                                    key: ValueKey(item.filename),
                                    item: item,
                                    deleteFocus: deleteNode,
                                    onDeleteKeyUp: () {
                                      if (isFirst) {
                                        _urlFocus.requestFocus();
                                      } else {
                                        onKeyUp();
                                      }
                                    },
                                    onDeleteKeyDown: onKeyDown,
                                    onDeleteKeyLeft: _backFocusNode.requestFocus,
                                    onDeleteKeyRight: _focusCatalogList,
                                    onDelete: () => _deleteRom(item),
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
        // Columna 2: Catálogo de Juegos Disponibles
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'arcade_available_column_title'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: widget.romManager.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: scheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : catalog.isEmpty
                        ? Center(
                            child: Text(
                              widget.romManager.errorMessage?.tr() ??
                                  'arcade_catalog_empty'.tr(),
                              style:
                                  MoaiText.body(context, color: scheme.error),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const windowSize = 4;
                              final availableH = constraints.maxHeight;
                              final itemExtent =
                                  (availableH / windowSize).floorToDouble();

                              return SizedBox(
                                height: availableH,
                                child: TvWindowedList<ArcadeRomItem>(
                                  key: _catalogListKey,
                                  items: catalog,
                                  windowSize: windowSize,
                                  itemExtent: itemExtent,
                                  showScrollDots: true,
                                  initialGlobalIndex: _selectedCatalogIndex,
                                  focusOnMount: false,
                                  onFocusedGlobalIndex: (idx) {
                                    _selectedCatalogIndex = idx;
                                  },
                                  onFocusUpFromFirst: _refreshFocus.requestFocus,
                                  itemBuilder: (
                                    context,
                                    item,
                                    focusNode,
                                    local,
                                    global,
                                    onKeyUp,
                                    onKeyDown,
                                  ) {
                                    final progress = widget.romManager
                                        .downloadProgress[item.filename];
                                    final isDownloading = progress != null;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 3),
                                      child: TvTile(
                                        focusNode: focusNode,
                                        minHeight: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        label: item.name,
                                        description:
                                            '${item.system} · ${item.year} · ${item.sizeLabel}',
                                        icon: MoaiIcons.arcadeRomItem,
                                        onPressed:
                                            item.isInstalled || isDownloading
                                                ? null
                                                : () => widget.romManager
                                                    .downloadRom(item),
                                        onKeyLeft: () {
                                          if (hasInstalled) {
                                            final targetIndex =
                                                _selectedInstalledIndex.clamp(
                                              0,
                                              _installedDeleteFocuses.length - 1,
                                            );
                                            _installedDeleteFocuses[targetIndex]
                                                .requestFocus();
                                          } else {
                                            _emptyFocusNode.requestFocus();
                                          }
                                        },
                                        onKeyUp: onKeyUp,
                                        onKeyDown: onKeyDown,
                                        trailingBuilder: (context, isFocused) =>
                                            TvInstallPill(
                                          isInstalled: item.isInstalled,
                                          isFocused: isFocused,
                                          downloadProgress: progress,
                                          installLabel: 'arcade_btn_install'.tr(),
                                          installedLabel:
                                              'arcade_badge_installed'.tr(),
                                          onPressed:
                                              item.isInstalled || isDownloading
                                                  ? null
                                                  : () => widget.romManager
                                                      .downloadRom(item),
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
      description: '${widget.item.sizeLabel} · ${'arcade_ready_to_play'.tr()}',
      icon: MoaiIcons.arcadeRomCard,
      trailing: _IconButtonAction(
        focusNode: widget.deleteFocus,
        tooltip: 'arcade_delete_btn'.tr(),
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
        if (TvKeyHandler.isActionKey(key)) {
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
