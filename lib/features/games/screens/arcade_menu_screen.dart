import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';

/// Pantalla intermedia de Arcade (Menú con panel único estilo Ajustes).
class ArcadeMenuScreen extends StatefulWidget {
  const ArcadeMenuScreen({super.key});

  @override
  State<ArcadeMenuScreen> createState() => _ArcadeMenuScreenState();
}

class _ArcadeMenuScreenState extends State<ArcadeMenuScreen> {
  final FocusNode _selectGameFocus = FocusNode(debugLabel: 'arcade_select_game');
  final FocusNode _gamepadFocus = FocusNode(debugLabel: 'arcade_config_gamepad');
  final FocusNode _startFocus = FocusNode(debugLabel: 'arcade_start_game');

  final String _currentGameName = 'Marvel vs. Capcom: Clash of Super Heroes';
  final String _currentGamePath = '/data/user/0/com.infomak.moai/files/mvsc.zip';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _selectGameFocus.dispose();
    _gamepadFocus.dispose();
    _startFocus.dispose();
    super.dispose();
  }

  void _onSelectGame() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Catálogo de juegos y descarga desde repositorio (próximamente)',
          style: MoaiText.body(context, color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onConfigGamepad() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mando físico detectado: D-Pad + 6 Botones Capcom CPS-2',
          style: MoaiText.body(context, color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade900,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onStartGame() {
    context.push(
      '/arcade/game',
      extra: _currentGamePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tvSettings = context.watch<TvSettingsProvider?>();
    final overlapX = tvSettings?.overlapPaddingX ?? 20.0;
    final overlapY = tvSettings?.overlapPaddingY ?? 20.0;

    return PopScope(
      canPop: true,
      child: FocusScope(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
               event.logicalKey == LogicalKeyboardKey.backspace)) {
            if (context.canPop()) {
              context.pop();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerLowest,
                scheme.surfaceContainerHigh,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                children: [
                  // Botón flotante para volver atrás
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    tooltip: 'Volver a TV',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const SizedBox(width: 16),

                  // Panel único estilo Ajustes (Tarjeta contenedora)
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxWidth: 760,
                          maxHeight: 520,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TvPanelHeader(
                              title: 'Arcade Retro',
                              subtitle: 'Centro de emulación FinalBurn Neo (CPS-2)',
                            ),
                            const SizedBox(height: 16),

                            // Fila 1: Seleccionar juego
                            TvSettingsActionRow(
                              focusNode: _selectGameFocus,
                              label: 'Seleccionar juego',
                              description: _currentGameName,
                              icon: Icons.sports_esports_outlined,
                              onPressed: _onSelectGame,
                              onKeyLeft: () => context.pop(),
                              onKeyDown: () => _gamepadFocus.requestFocus(),
                            ),
                            const SizedBox(height: 10),

                            // Fila 2: Configurar Gamepad
                            TvSettingsActionRow(
                              focusNode: _gamepadFocus,
                              label: 'Configurar Gamepad',
                              description: 'Mando físico (Bluetooth / USB) — 6 botones CPS-2',
                              icon: Icons.videogame_asset_outlined,
                              onPressed: _onConfigGamepad,
                              onKeyLeft: () => context.pop(),
                              onKeyUp: () => _selectGameFocus.requestFocus(),
                              onKeyDown: () => _startFocus.requestFocus(),
                            ),
                            const SizedBox(height: 10),

                            // Fila 3: Iniciar Juego
                            TvSettingsActionRow(
                              focusNode: _startFocus,
                              label: 'Iniciar juego',
                              description: 'Arrancar emulador nativo a 60 FPS',
                              icon: Icons.play_arrow_rounded,
                              onPressed: _onStartGame,
                              onKeyLeft: () => context.pop(),
                              onKeyUp: () => _gamepadFocus.requestFocus(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
