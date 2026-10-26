import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/games/arcade_launcher.dart';
import 'package:moai3/features/games/screens/arcade_games_screen.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/dialogs/tv_gamepad_config_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Área principal de Arcade en HomeScreen: 1 único panel con el mismo diseño que Ajustes.
class HomeArcadeArea extends StatefulWidget {
  final VoidCallback onExitLeft;
  final ArcadeRomManagerService romManager;

  const HomeArcadeArea({
    super.key,
    required this.onExitLeft,
    required this.romManager,
  });

  @override
  State<HomeArcadeArea> createState() => _HomeArcadeAreaState();
}

class _HomeArcadeAreaState extends HomeAreaState<HomeArcadeArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _selectGameFocus = FocusNode(debugLabel: 'arcade_select_game');
  final _gamepadFocus = FocusNode(debugLabel: 'arcade_config_gamepad');
  final _startFocus = FocusNode(debugLabel: 'arcade_start_game');
  final _playTogetherFocus = FocusNode(debugLabel: 'arcade_play_together');

  @override
  void initState() {
    super.initState();
    widget.romManager.addListener(_onRomManagerUpdate);
  }

  @override
  void dispose() {
    widget.romManager.removeListener(_onRomManagerUpdate);
    _selectGameFocus.dispose();
    _gamepadFocus.dispose();
    _startFocus.dispose();
    _playTogetherFocus.dispose();
    super.dispose();
  }

  @override
  void requestEntryFocus() => _focus.node(_selectGameFocus, immediate: true);

  void _onStartGame() {
    final path = widget.romManager.getActiveRomPath();
    if (path != null) {
      unawaited(ArcadeLauncher.play(context, romPath: path));
    } else {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.arcade_no_game_installed_snack.tr(),
        icon: MoaiIcons.info,
      );
    }
  }

  void _onRomManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _onSelectGame() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArcadeGamesScreen(romManager: widget.romManager),
      ),
    );
  }

  String _resolveCurrentGameName() {
    final installed = widget.romManager.installedRoms;
    if (installed.isEmpty) {
      return LocaleKeys.arcade_no_games_installed.tr();
    }
    final active = installed.firstWhere(
      (r) =>
          r.filename.toLowerCase() ==
          widget.romManager.activeRomFilename?.toLowerCase(),
      orElse: () => installed.first,
    );
    return widget.romManager.displayNameOf(active);
  }

  void _onConfigGamepad() {
    TvGamepadConfigDialog.show(context);
  }

  void _onPlayTogether() =>
      ArcadeLauncher.playTogether(context, widget.romManager);

  @override
  Widget build(BuildContext context) {
    final canPlayTogether =
        context.watch<WatchPartyProvider?>()?.hasOnlineFriends ?? false;
    if (!canPlayTogether && _playTogetherFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_startFocus.hasFocus) {
          _startFocus.requestFocus();
        }
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final panelColors = [scheme.surface.withValues(alpha: 0.8)];
    final titles = [LocaleKeys.arcade_panel_title.tr()];
    const icons = [MoaiIcons.gamepad];

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: panelColors,
      titles: titles,
      icons: icons,
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        return Container(
          padding: const EdgeInsets.only(
            left: 16,
            right: 24,
            top: 12,
            bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TvPanelHeader(
                title: LocaleKeys.arcade_panel_title.tr(),
                subtitle: LocaleKeys.arcade_panel_subtitle.tr(),
              ),
              const SizedBox(height: 16),

              // 1. Seleccionar juego
              TvSettingsActionRow(
                focusNode: _selectGameFocus,
                label: LocaleKeys.arcade_action_select_game.tr(),
                description: _resolveCurrentGameName(),
                icon: MoaiIcons.arcadeActionSelectGame,
                onPressed: _onSelectGame,
                onKeyLeft: widget.onExitLeft,
                onKeyDown: _gamepadFocus.requestFocus,
              ),
              const SizedBox(height: 10),

              // 2. Configurar Gamepad
              TvSettingsActionRow(
                focusNode: _gamepadFocus,
                label: LocaleKeys.arcade_gamepad_config_title.tr(),
                description: LocaleKeys.arcade_gamepad_config_desc.tr(),
                icon: MoaiIcons.arcadeActionConfigGamepad,
                onPressed: _onConfigGamepad,
                onKeyLeft: widget.onExitLeft,
                onKeyUp: _selectGameFocus.requestFocus,
                onKeyDown: widget.romManager.installedRoms.isNotEmpty
                    ? _startFocus.requestFocus
                    : null,
              ),

              // 3. Iniciar juego (solo si hay ROMs descargadas/instaladas)
              if (widget.romManager.installedRoms.isNotEmpty) ...[
                const SizedBox(height: 10),
                TvSettingsActionRow(
                  focusNode: _startFocus,
                  label: LocaleKeys.arcade_action_start_game.tr(),
                  description: LocaleKeys.arcade_action_start_game_desc.tr(),
                  icon: MoaiIcons.arcadeActionStartGame,
                  onPressed: _onStartGame,
                  onKeyLeft: widget.onExitLeft,
                  onKeyUp: _gamepadFocus.requestFocus,
                  onKeyDown: canPlayTogether
                      ? _playTogetherFocus.requestFocus
                      : null,
                ),
                if (canPlayTogether) ...[
                  const SizedBox(height: 10),
                  TvSettingsActionRow(
                    focusNode: _playTogetherFocus,
                    label: LocaleKeys.arcade_action_play_together.tr(),
                    description: LocaleKeys.arcade_action_play_together_desc
                        .tr(),
                    icon: MoaiIcons.friends,
                    onPressed: _onPlayTogether,
                    onKeyLeft: widget.onExitLeft,
                    onKeyUp: _startFocus.requestFocus,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
