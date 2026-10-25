import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Diálogo modal estándar de TV para sincronizar la preparación y descarga de ROMs
/// entre dos jugadores a la distancia antes de iniciar la partida.
class TvArcadePrepDialog extends StatefulWidget {
  final void Function(ArcadeNetplaySession session) onReadyToPlay;

  const TvArcadePrepDialog({
    super.key,
    required this.onReadyToPlay,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(ArcadeNetplaySession session) onReadyToPlay,
  }) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'TvArcadePrepDialog',
      builder: (dialogContext) => TvArcadePrepDialog(
        onReadyToPlay: onReadyToPlay,
      ),
    );
  }

  @override
  State<TvArcadePrepDialog> createState() => _TvArcadePrepDialogState();
}

class _TvArcadePrepDialogState extends State<TvArcadePrepDialog> {
  final FocusNode _cancelFocus = FocusNode(debugLabel: 'netplay_prep_cancel_btn');
  final ArcadeNetplayService _netplay = ArcadeNetplayService.instance;
  bool _hasStartedGame = false;

  @override
  void initState() {
    super.initState();
    _netplay.addListener(_onNetplayUpdated);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cancelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _netplay.removeListener(_onNetplayUpdated);
    _cancelFocus.dispose();
    super.dispose();
  }

  void _onNetplayUpdated() {
    if (!mounted) return;
    final session = _netplay.currentSession;

    // Si la sesión terminó o fue cancelada
    if (session == null || session.status == ArcadeNetplayStatus.terminated) {
      final reason =
          session?.exitReason ?? LocaleKeys.arcade_session_canceled_default.tr();
      Navigator.of(context, rootNavigator: true).pop();
      MoaiSnackBar.show(context, message: reason);
      return;
    }

    // ROM lista + WebRTC conectado (inGame). "ready" = aún negociando P2P.
    if (session.status == ArcadeNetplayStatus.inGame && !_hasStartedGame) {
      _hasStartedGame = true;
      Navigator.of(context, rootNavigator: true).pop();
      widget.onReadyToPlay(session);
    } else {
      setState(() {});
    }
  }

  void _onCancel() {
    _netplay.cancelSession(reason: LocaleKeys.arcade_session_canceled_by_user.tr());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = _netplay.currentSession;

    if (session == null) {
      return const SizedBox.shrink();
    }

    final isHost = session.isHost;
    final gameTitle = session.romName;
    final friendName = session.peerNickname;

    return TvDialog(
      width: 560,
      icon: MoaiIcons.gamepad,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: LocaleKeys.arcade_prep_title.tr(namedArgs: {'game': gameTitle}),
      subtitle: isHost
          ? LocaleKeys.arcade_prep_subtitle_host.tr(namedArgs: {'friend': friendName})
          : LocaleKeys.arcade_prep_subtitle_guest.tr(namedArgs: {'friend': friendName}),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Estado local (Tu consola)
          _buildProgressBlock(
            label: LocaleKeys.arcade_prep_status_local
                .tr(namedArgs: {'name': session.myNickname}),
            statusText: session.myStatusText,
            progress: session.myProgress,
            activeColor: scheme.primary,
            isDone: session.myProgress >= 1.0,
            context: context,
          ),

          const SizedBox(height: 18),

          // 2. Estado del amigo (Consola remota)
          _buildProgressBlock(
            label: LocaleKeys.arcade_prep_status_remote
                .tr(namedArgs: {'friend': friendName}),
            statusText: session.peerStatusText,
            progress: session.peerProgress,
            activeColor: scheme.tertiary,
            isDone: session.peerProgress >= 1.0,
            context: context,
          ),

          const SizedBox(height: 14),

          // Mensaje explicativo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: moaiGlassWellDecoration(scheme, radius: 12),
            child: Row(
              children: [
                Icon(
                  MoaiIcons.infoCircle,
                  size: MoaiIconSizes.md,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocaleKeys.arcade_prep_info.tr(),
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _cancelFocus,
          label: LocaleKeys.arcade_prep_cancel.tr(),
          onPressed: _onCancel,
        ),
      ],
    );
  }

  Widget _buildProgressBlock({
    required String label,
    required String statusText,
    required double progress,
    required Color activeColor,
    required bool isDone,
    required BuildContext context,
  }) {
    final scheme = Theme.of(context).colorScheme;
    // "Pozo" de cristal; al terminar, el borde toma el color del paso.
    final well = moaiGlassWellDecoration(scheme, radius: 14);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: isDone
          ? well.copyWith(
              border: Border.all(
                color: activeColor.withValues(alpha: 0.4),
                width: 1.2,
              ),
            )
          : well,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: MoaiText.body(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              Row(
                children: [
                  if (isDone)
                    Icon(MoaiIcons.checkCircleFilled, size: MoaiIconSizes.sm, color: activeColor)
                  else if (progress > 0.0 && progress < 1.0)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: isDone ? activeColor : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: (scheme.brightness == Brightness.dark ? Colors.white : scheme.onSurface).withValues(alpha: 0.10),
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ],
      ),
    );
  }
}
