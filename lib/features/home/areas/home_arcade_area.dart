import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/games/screens/arcade_games_screen.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';

/// Área principal de Arcade en HomeScreen: 1 único panel con el mismo diseño que Ajustes.
class HomeArcadeArea extends StatefulWidget {
  final FocusNode selectGameFocus;
  final FocusNode gamepadFocus;
  final FocusNode startFocus;
  final VoidCallback onExitLeft;
  final VoidCallback onStartGame;
  final ArcadeRomManagerService romManager;

  const HomeArcadeArea({
    super.key,
    required this.selectGameFocus,
    required this.gamepadFocus,
    required this.startFocus,
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
      return 'arcade_no_games_installed'.tr();
    }
    final active = installed.firstWhere(
      (r) => r.filename == widget.romManager.activeRomFilename,
      orElse: () => installed.first,
    );
    return active.name;
  }

  void _onConfigGamepad() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'arcade_gamepad_detected_snack'.tr(),
          style: MoaiText.body(context, color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panelColors = [
      scheme.surface.withValues(alpha: 0.8),
    ];
    final titles = [
      'arcade_panel_title'.tr(),
    ];
    const icons = [
      Icons.sports_esports_outlined,
    ];

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
                title: 'arcade_panel_title'.tr(),
                subtitle: 'arcade_panel_subtitle'.tr(),
              ),
              const SizedBox(height: 16),

              // 1. Seleccionar juego
              TvSettingsActionRow(
                focusNode: widget.selectGameFocus,
                label: 'arcade_action_select_game'.tr(),
                description: _resolveCurrentGameName(),
                icon: Icons.sports_esports_outlined,
                onPressed: _onSelectGame,
                onKeyLeft: widget.onExitLeft,
                onKeyDown: () => widget.gamepadFocus.requestFocus(),
              ),
              const SizedBox(height: 10),

              // 2. Configurar Gamepad
              TvSettingsActionRow(
                focusNode: widget.gamepadFocus,
                label: 'arcade_gamepad_config_title'.tr(),
                description: 'arcade_gamepad_config_desc'.tr(),
                icon: Icons.videogame_asset_outlined,
                onPressed: _onConfigGamepad,
                onKeyLeft: widget.onExitLeft,
                onKeyUp: () => widget.selectGameFocus.requestFocus(),
                onKeyDown: () => widget.startFocus.requestFocus(),
              ),
              const SizedBox(height: 10),

              // 3. Iniciar juego
              TvSettingsActionRow(
                focusNode: widget.startFocus,
                label: 'arcade_action_start_game'.tr(),
                description: 'arcade_action_start_game_desc'.tr(),
                icon: Icons.play_arrow_rounded,
                onPressed: widget.onStartGame,
                onKeyLeft: widget.onExitLeft,
                onKeyUp: () => widget.gamepadFocus.requestFocus(),
              ),
            ],
          ),
        );
      },
    );
  }
}
