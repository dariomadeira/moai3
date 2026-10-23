import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/games/widgets/tv_arcade_prep_dialog.dart';

/// Argumentos tipados de la ruta `/arcade/game`.
class ArcadeGameArgs {
  const ArcadeGameArgs({this.romPath, this.session});

  final String? romPath;

  /// Partida online ya preparada; `null` para jugar solo.
  final ArcadeNetplaySession? session;
}

/// Única forma de abrir el juego Arcade (SPEC-50 §5.7).
abstract final class ArcadeLauncher {
  static const route = '/arcade/game';

  static Future<void> play(
    BuildContext context, {
    String? romPath,
    ArcadeNetplaySession? session,
  }) =>
      context.push(
        route,
        extra: ArcadeGameArgs(romPath: romPath, session: session),
      );

  /// Diálogo de preparación de la partida online y, cuando ambos están
  /// listos, el juego con la ROM activa.
  static Future<void> prepareAndPlay(
    BuildContext context,
    ArcadeRomManagerService romManager,
  ) =>
      TvArcadePrepDialog.show(
        context,
        onReadyToPlay: (session) => play(
          context,
          romPath: romManager.getActiveRomPath(),
          session: session,
        ),
      );
}
