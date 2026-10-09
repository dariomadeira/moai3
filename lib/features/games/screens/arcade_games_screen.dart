import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
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
  final FocusNode _backFocus = FocusNode(debugLabel: 'games_back');
  final FocusNode _urlFocus = FocusNode(debugLabel: 'games_url');
  final FocusNode _refreshFocus = FocusNode(debugLabel: 'games_refresh');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'games_empty');

  final List<FocusNode> _installedDeleteFocuses = [];
  final List<FocusNode> _catalogFocuses = [];

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

    final catalog = widget.romManager.catalog;
    while (_catalogFocuses.length < catalog.length) {
      _catalogFocuses.add(
        FocusNode(debugLabel: 'catalog_${_catalogFocuses.length}'),
      );
    }
  }

  @override
  void dispose() {
    widget.romManager.removeListener(_onManagerUpdated);
    _urlController.dispose();
    _backFocus.dispose();
    _urlFocus.dispose();
    _refreshFocus.dispose();
    _emptyFocusNode.dispose();
    for (final f in _installedDeleteFocuses) {
      f.dispose();
    }
    for (final f in _catalogFocuses) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _deleteRomDialog(ArcadeRomItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = ctx.scheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'arcade_delete_dialog_title'.tr(),
            style: MoaiText.display(ctx, color: scheme.onSurface, fontSize: 18),
          ),
          content: Text(
            'arcade_delete_dialog_desc'.tr(namedArgs: {
              'name': item.name,
              'size': item.sizeLabel,
            }),
            style: MoaiText.body(ctx, color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common_cancel'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('arcade_delete_btn'.tr(), style: TextStyle(color: scheme.onError)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await widget.romManager.deleteRom(item.filename);
      _syncFocusNodes();
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFocusNodes();
    final scheme = context.scheme;
    final installed = widget.romManager.installedRoms;
    final catalog = widget.romManager.catalog;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, scheme, installed.length, catalog.length),
              const SizedBox(height: 18),
              _buildUrlRow(context, scheme),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna 1: Juegos Instalados
                    Expanded(
                      flex: 5,
                      child: _buildInstalledColumn(context, scheme, installed),
                    ),
                    const SizedBox(width: 24),
                    // Columna 2: Catálogo de Juegos Disponibles
                    Expanded(
                      flex: 5,
                      child: _buildCatalogColumn(context, scheme, catalog),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme scheme,
    int installedCount,
    int catalogCount,
  ) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.sports_esports,
              color: scheme.onPrimaryContainer,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'arcade_games_title'.tr(),
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'arcade_games_subtitle'.tr(),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                installedCount == 1
                    ? 'arcade_installed_count_single'.tr(namedArgs: {'count': '1'})
                    : 'arcade_installed_count_plural'.tr(namedArgs: {'count': installedCount.toString()}),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUrlRow(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _urlController,
            focusNode: _urlFocus,
            label: 'arcade_input_url_label'.tr(),
            hint: 'arcade_input_url_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            doneLabel: 'arcade_input_url_done'.tr(),
            leadingIcon: Icons.link_rounded,
            onSubmitted: (val) => _loadData(),
            onFocusLeft: () => _backFocus.requestFocus(),
            onFocusRight: () => _refreshFocus.requestFocus(),
            onFocusUp: () => _backFocus.requestFocus(),
            onFocusDown: () {
              if (_installedDeleteFocuses.isNotEmpty) {
                _installedDeleteFocuses.first.requestFocus();
              } else if (_catalogFocuses.isNotEmpty) {
                _catalogFocuses.first.requestFocus();
              } else {
                _emptyFocusNode.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        TvFocusButton(
          focusNode: _refreshFocus,
          label: 'arcade_btn_refresh'.tr(),
          icon: Icons.refresh_rounded,
          height: 60,
          variant: TvButtonVariant.tonal,
          onPressed: () => _loadData(),
          onArrowLeft: () => _urlFocus.requestFocus(),
          onArrowUp: () => _backFocus.requestFocus(),
          onArrowDown: () {
            if (_catalogFocuses.isNotEmpty) {
              _catalogFocuses.first.requestFocus();
            } else if (_installedDeleteFocuses.isNotEmpty) {
              _installedDeleteFocuses.first.requestFocus();
            }
          },
        ),
      ],
    );
  }

  Widget _buildInstalledColumn(
    BuildContext context,
    ColorScheme scheme,
    List<ArcadeRomItem> installed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'arcade_installed_column_title'.tr(),
          style: MoaiText.body(
            context,
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: installed.isEmpty
              ? TvEmptyStateCard(
                  focusNode: _emptyFocusNode,
                  icon: Icons.sports_esports_outlined,
                  message: 'arcade_empty_installed_msg'.tr(),
                  onFocusUp: () => _urlFocus.requestFocus(),
                  onFocusRight: () {
                    if (_catalogFocuses.isNotEmpty) {
                      _catalogFocuses.first.requestFocus();
                    }
                  },
                )
              : ListView.builder(
                  itemCount: installed.length,
                  itemBuilder: (context, i) {
                    final item = installed[i];
                    final isLast = i == installed.length - 1;
                    return _InstalledRomCard(
                      key: ValueKey(item.filename),
                      item: item,
                      deleteFocusNode: _installedDeleteFocuses[i],
                      onDelete: () => _deleteRomDialog(item),
                      onKeyUp: () {
                        if (i == 0) {
                          _urlFocus.requestFocus();
                        } else {
                          _installedDeleteFocuses[i - 1].requestFocus();
                        }
                      },
                      onKeyDown: () {
                        if (!isLast) {
                          _installedDeleteFocuses[i + 1].requestFocus();
                        }
                      },
                      onKeyRight: () {
                        if (_catalogFocuses.isNotEmpty) {
                          final target = i.clamp(0, _catalogFocuses.length - 1);
                          _catalogFocuses[target].requestFocus();
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCatalogColumn(
    BuildContext context,
    ColorScheme scheme,
    List<ArcadeRomItem> catalog,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'arcade_available_column_title'.tr(),
          style: MoaiText.body(
            context,
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: widget.romManager.isLoading
              ? const Center(child: CircularProgressIndicator())
              : catalog.isEmpty
                  ? Center(
                      child: Text(
                        widget.romManager.errorMessage ?? 'arcade_catalog_empty'.tr(),
                        style: MoaiText.body(context, color: scheme.error),
                      ),
                    )
                  : ListView.builder(
                      itemCount: catalog.length,
                      itemBuilder: (context, i) {
                        final item = catalog[i];
                        final progress =
                            widget.romManager.downloadProgress[item.filename];
                        return _CatalogRomTile(
                          key: ValueKey(item.id),
                          item: item,
                          focusNode: _catalogFocuses[i],
                          downloadProgress: progress,
                          onInstall: () => widget.romManager.downloadRom(item),
                          onKeyLeft: () {
                            if (_installedDeleteFocuses.isNotEmpty) {
                              final target =
                                  i.clamp(0, _installedDeleteFocuses.length - 1);
                              _installedDeleteFocuses[target].requestFocus();
                            } else {
                              _emptyFocusNode.requestFocus();
                            }
                          },
                          onKeyUp: () {
                            if (i == 0) {
                              _refreshFocus.requestFocus();
                            } else {
                              _catalogFocuses[i - 1].requestFocus();
                            }
                          },
                          onKeyDown: () {
                            if (i < catalog.length - 1) {
                              _catalogFocuses[i + 1].requestFocus();
                            }
                          },
                        );
                      },
                    ),
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

class _InstalledRomCard extends StatefulWidget {
  final ArcadeRomItem item;
  final FocusNode deleteFocusNode;
  final VoidCallback onDelete;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback? onKeyRight;

  const _InstalledRomCard({
    super.key,
    required this.item,
    required this.deleteFocusNode,
    required this.onDelete,
    required this.onKeyUp,
    required this.onKeyDown,
    this.onKeyRight,
  });

  @override
  State<_InstalledRomCard> createState() => _InstalledRomCardState();
}

class _InstalledRomCardState extends State<_InstalledRomCard> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.deleteFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.deleteFocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.deleteFocusNode.hasFocus);
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
                  Icons.sports_esports,
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
                    widget.item.name,
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
                    '${widget.item.sizeLabel} · ${'arcade_ready_to_play'.tr()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: descColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Botón Tacho de Basura
            Focus(
              focusNode: widget.deleteFocusNode,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.arrowUp) {
                  widget.onKeyUp();
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  widget.onKeyDown();
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
                  widget.onDelete();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: AnimatedScale(
                scale: _isFocused ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Material(
                  color: _isFocused
                      ? scheme.errorContainer
                      : scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: _isFocused
                            ? scheme.onErrorContainer
                            : scheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogRomTile extends StatefulWidget {
  final ArcadeRomItem item;
  final FocusNode focusNode;
  final double? downloadProgress;
  final VoidCallback onInstall;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  const _CatalogRomTile({
    super.key,
    required this.item,
    required this.focusNode,
    this.downloadProgress,
    required this.onInstall,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
  });

  @override
  State<_CatalogRomTile> createState() => _CatalogRomTileState();
}

class _CatalogRomTileState extends State<_CatalogRomTile> {
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
    final titleColor = _isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    final isDownloading = widget.downloadProgress != null;

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
            if (!widget.item.isInstalled && !isDownloading) {
              widget.onInstall();
            }
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
            onTap: widget.item.isInstalled || isDownloading ? null : widget.onInstall,
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
                      Icons.videogame_asset_outlined,
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
                        widget.item.name,
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
                        '${widget.item.system} · ${widget.item.year} · ${widget.item.sizeLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: descColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Botón o Badge según estado
                if (widget.item.isInstalled)
                  Material(
                    color: _isFocused
                        ? scheme.onPrimary.withValues(alpha: 0.2)
                        : scheme.tertiaryContainer,
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
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: _isFocused
                                ? scheme.onPrimary
                                : scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'arcade_badge_installed'.tr(),
                            style: MoaiText.body(
                              context,
                              color: _isFocused
                                  ? scheme.onPrimary
                                  : scheme.onTertiaryContainer,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isDownloading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: widget.downloadProgress! > 0
                                ? widget.downloadProgress
                                : null,
                            color: _isFocused ? scheme.onPrimary : scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(widget.downloadProgress! * 100).toInt()}%',
                          style: MoaiText.body(
                            context,
                            color: _isFocused ? scheme.onPrimary : scheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Material(
                    color: _isFocused ? scheme.onPrimary : scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.download,
                            size: 16,
                            color: _isFocused ? scheme.primary : scheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'arcade_btn_install'.tr(),
                            style: MoaiText.body(
                              context,
                              color: _isFocused ? scheme.primary : scheme.onPrimary,
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
