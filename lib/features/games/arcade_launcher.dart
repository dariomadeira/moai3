import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/games/widgets/tv_arcade_prep_dialog.dart';
import 'package:moai3/features/games/widgets/tv_arcade_select_friend_dialog.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:provider/provider.dart';

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

  /// "Jugar juntos" / "Invitar": elegir un amigo conectado, mandarle la
  /// invitación con el juego cargado y, si la acepta, preparar la partida.
  /// Lo usan la sección Arcade y la tarjeta del Inicio.
  static void playTogether(
    BuildContext context,
    ArcadeRomManagerService romManager,
  ) {
    final path = romManager.getActiveRomPath();
    if (path == null || romManager.installedRoms.isEmpty) {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.arcade_no_game_installed_snack.tr(),
        icon: MoaiIcons.info,
      );
      return;
    }

    final activeRom = romManager.installedRoms.firstWhere(
      (r) =>
          r.filename.toLowerCase() ==
          romManager.activeRomFilename?.toLowerCase(),
      orElse: () => romManager.installedRoms.first,
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
          romManager: romManager,
        );

        if (ok && context.mounted) {
          unawaited(prepareAndPlay(context, romManager));
        }
      },
    );
  }

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
