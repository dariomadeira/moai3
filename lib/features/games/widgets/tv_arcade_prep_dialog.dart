import 'package:flutter/material.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

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
      final reason = session?.exitReason ?? 'La partida fue cancelada';
      Navigator.of(context, rootNavigator: true).pop();
      MoaiSnackBar.show(context, message: reason);
      return;
    }

    // Si ambos están 100% listos para arrancar
    if (session.status == ArcadeNetplayStatus.ready && !_hasStartedGame) {
      _hasStartedGame = true;
      Navigator.of(context, rootNavigator: true).pop();
      widget.onReadyToPlay(session);
    } else {
      setState(() {});
    }
  }

  void _onCancel() {
    _netplay.cancelSession(reason: 'Partida cancelada por el usuario');
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
      icon: Icons.sports_esports_rounded,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: 'Jueguen Juntos: $gameTitle',
      subtitle: isHost
          ? 'Sincronizando con $friendName...'
          : 'Invitación de $friendName...',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Estado local (Tu consola)
          _buildProgressBlock(
            label: 'Tu estado (${session.myNickname})',
            statusText: session.myStatusText,
            progress: session.myProgress,
            activeColor: scheme.primary,
            isDone: session.myProgress >= 1.0,
            context: context,
          ),

          const SizedBox(height: 18),

          // 2. Estado del amigo (Consola remota)
          _buildProgressBlock(
            label: 'Estado de $friendName',
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
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ambas consolas deben tener el juego listo para arrancar en simultáneo sin cortes.',
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
          label: 'Cancelar partida',
          variant: TvDialogButtonVariant.neutral,
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDone ? activeColor.withValues(alpha: 0.4) : scheme.outlineVariant.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
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
                    Icon(Icons.check_circle_rounded, size: 16, color: activeColor)
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
                      fontWeight: FontWeight.w600,
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
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ],
      ),
    );
  }
}
