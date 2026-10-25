import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'package:moai3/widgets/buttons/tv_icon_action_button.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';

part 'arcade_games/arcade_games_layout.dart';
part 'arcade_games/installed_rom_tile.dart';

/// Pantalla para gestionar y descargar ROMs de Arcade.
/// Sigue la misma estructura y diseño de 2 columnas que SourcesScreen.
class ArcadeGamesScreen extends StatefulWidget {
  final ArcadeRomManagerService romManager;

  const ArcadeGamesScreen({super.key, required this.romManager});

  @override
  State<ArcadeGamesScreen> createState() => _ArcadeGamesScreenState();
}

class _ArcadeGamesScreenState extends State<ArcadeGamesScreen> {
  final TextEditingController _urlController = TextEditingController(
    text: ArcadeRomManagerService.defaultManifestUrl,
  );
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
        FocusNode(
          debugLabel: 'installed_del_${_installedDeleteFocuses.length}',
        ),
      );
    }
  }

  void _focusCatalogList() {
    if (widget.romManager.catalog.isEmpty) return;
    final index = _selectedCatalogIndex.clamp(
      0,
      widget.romManager.catalog.length - 1,
    );
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
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
                              ? () =>
                                    _installedDeleteFocuses.first.requestFocus()
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
                        titles: [LocaleKeys.arcade_action_select_game.tr()],
                        icons: const [MoaiIcons.arcadeRomItem],
                        onPanelTap: (_) {},
                        tabBuilder: (index, isExpanded) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14, top: 14),
                            child: Column(
                              children: [
                                const Spacer(),
                                RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    LocaleKeys.arcade_action_select_game.tr(),
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
                                        title: LocaleKeys.arcade_games_title
                                            .tr(),
                                        subtitle: LocaleKeys
                                            .arcade_games_subtitle
                                            .tr(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    if (installedCount > 0) ...[
                                      const SizedBox(width: 12),
                                      TvMetaPill(
                                        icon: MoaiIcons.arcadeRomInstalledBadge,
                                        label: installedCount == 1
                                            ? LocaleKeys
                                                  .arcade_installed_count_single
                                                  .tr(namedArgs: {'count': '1'})
                                            : LocaleKeys
                                                  .arcade_installed_count_plural
                                                  .tr(
                                                    namedArgs: {
                                                      'count': installedCount
                                                          .toString(),
                                                    },
                                                  ),
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
                                            MoaiIcons.error,
                                            color: scheme.onErrorContainer,
                                            size: MoaiIconSizes.md,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.romManager.errorMessage!
                                                  .tr(),
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
    );
  }
}
