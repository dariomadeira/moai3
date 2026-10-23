import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/games/arcade_launcher.dart';
import 'package:moai3/features/games/screens/arcade_games_screen.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/games/widgets/tv_arcade_select_friend_dialog.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/dialogs/tv_gamepad_config_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Área principal de Arcade en HomeScreen: 1 único panel con el mismo diseño que Ajustes.
class HomeArcadeArea extends StatefulWidget {
  final FocusNode selectGameFocus;
  final FocusNode gamepadFocus;
  final FocusNode startFocus;
  final FocusNode playTogetherFocus;
  final VoidCallback onExitLeft;
  final VoidCallback onStartGame;
  final ArcadeRomManagerService romManager;

  const HomeArcadeArea({
    super.key,
    required this.selectGameFocus,
    required this.gamepadFocus,
    required this.startFocus,
    required this.playTogetherFocus,
    required this.onExitLeft,
    required this.onStartGame,
    required this.romManager,
  });

  @override
  State<HomeArcadeArea> createState() => _HomeArcadeAreaState();
}

class _HomeArcadeAreaState extends State<HomeArcadeArea> {
  @override
  void initState() {
    super.initState();
    widget.romManager.addListener(_onRomManagerUpdate);
  }

  @override
  void dispose() {
    widget.romManager.removeListener(_onRomManagerUpdate);
    super.dispose();
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
    if (active.name.isNotEmpty &&
        active.name.toLowerCase() !=
            active.filename.toLowerCase().replaceAll('.zip', '')) {
      return active.name;
    }
    return widget.romManager.nameFromFilename(active.filename);
  }

  void _onConfigGamepad() {
    TvGamepadConfigDialog.show(context);
  }

  void _onPlayTogether() {
    final path = widget.romManager.getActiveRomPath();
    if (path == null || widget.romManager.installedRoms.isEmpty) {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.arcade_no_game_installed_snack.tr(),
        icon: MoaiIcons.infoOutline,
      );
      return;
    }

    final activeRom = widget.romManager.installedRoms.firstWhere(
      (r) =>
          r.filename.toLowerCase() ==
          widget.romManager.activeRomFilename?.toLowerCase(),
      orElse: () => widget.romManager.installedRoms.first,
    );

    final identity = context.read<DeviceIdentityService>();
    final myDeviceId = identity.getOrCreateDeviceId();
    final myNickname =
        context.read<WatchPartyProvider?>()?.myNickname ??
        LocaleKeys.arcade_player_default.tr();

    TvArcadeSelectFriendDialog.show(
      context,
      onFriendSelected: (friend) async {
        final ok = await ArcadeNetplayService.instance.inviteFriend(
          myDeviceId: myDeviceId,
          myNickname: myNickname,
          peerDeviceId: friend.deviceId,
          peerNickname: friend.displayName,
          rom: activeRom,
          romManager: widget.romManager,
        );

        if (ok && mounted) {
          unawaited(ArcadeLauncher.prepareAndPlay(context, widget.romManager));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPlayTogether =
        context.watch<WatchPartyProvider?>()?.hasOnlineFriends ?? false;
    if (!canPlayTogether && widget.playTogetherFocus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.startFocus.hasFocus) {
          widget.startFocus.requestFocus();
        }
      });
    }

    final scheme = Theme.of(context).colorScheme;
    final panelColors = [scheme.surface.withValues(alpha: 0.8)];
    final titles = [LocaleKeys.arcade_panel_title.tr()];
    const icons = [MoaiIcons.sportsEsportsOutlined];

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
                focusNode: widget.selectGameFocus,
                label: LocaleKeys.arcade_action_select_game.tr(),
                description: _resolveCurrentGameName(),
                icon: MoaiIcons.arcadeActionSelectGame,
                onPressed: _onSelectGame,
                onKeyLeft: widget.onExitLeft,
                onKeyDown: () => widget.gamepadFocus.requestFocus(),
              ),
              const SizedBox(height: 10),

              // 2. Configurar Gamepad
              TvSettingsActionRow(
                focusNode: widget.gamepadFocus,
                label: LocaleKeys.arcade_gamepad_config_title.tr(),
                description: LocaleKeys.arcade_gamepad_config_desc.tr(),
                icon: MoaiIcons.arcadeActionConfigGamepad,
                onPressed: _onConfigGamepad,
                onKeyLeft: widget.onExitLeft,
                onKeyUp: () => widget.selectGameFocus.requestFocus(),
                onKeyDown: widget.romManager.installedRoms.isNotEmpty
                    ? () => widget.startFocus.requestFocus()
                    : null,
              ),

              // 3. Iniciar juego (solo si hay ROMs descargadas/instaladas)
              if (widget.romManager.installedRoms.isNotEmpty) ...[
                const SizedBox(height: 10),
                TvSettingsActionRow(
                  focusNode: widget.startFocus,
                  label: LocaleKeys.arcade_action_start_game.tr(),
                  description: LocaleKeys.arcade_action_start_game_desc.tr(),
                  icon: MoaiIcons.arcadeActionStartGame,
                  onPressed: widget.onStartGame,
                  onKeyLeft: widget.onExitLeft,
                  onKeyUp: () => widget.gamepadFocus.requestFocus(),
                  onKeyDown: canPlayTogether
                      ? () => widget.playTogetherFocus.requestFocus()
                      : null,
                ),
                if (canPlayTogether) ...[
                  const SizedBox(height: 10),
                  TvSettingsActionRow(
                    focusNode: widget.playTogetherFocus,
                    label: LocaleKeys.arcade_action_play_together.tr(),
                    description: LocaleKeys.arcade_action_play_together_desc.tr(),
                    icon: MoaiIcons.groupOutlined,
                    onPressed: _onPlayTogether,
                    onKeyLeft: widget.onExitLeft,
                    onKeyUp: () => widget.startFocus.requestFocus(),
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
