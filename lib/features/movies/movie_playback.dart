import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/movies/screens/movie_player_screen.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

/// Pide el video de [movie] y lo abre en el reproductor (desde [startAt] si
/// se retoma). Si no se puede, avisa con un mensaje claro (el detalle
/// técnico va al log). Termina cuando se cierra el reproductor.
///
/// La usan el detalle (Reproducir) y "Seguir viendo" del Inicio.
/// [resolveStream] reemplaza a [MoiamovApiService] en los tests.
Future<void> playMovie(
  BuildContext context,
  MovieItem movie, {
  int? startAt,
  bool saveProgress = true,
  SeriesPlaylist? series,
  Future<ResolvedPlayStream?> Function(MovieItem movie)? resolveStream,
}) async {
  try {
    final resolve =
        resolveStream ??
        (movie) => MoiamovApiService.instance.resolveMovieStream(movie: movie);
    final stream = await resolve(movie);
    if (!context.mounted) return;

    if (stream == null || stream.directHlsUrl.isEmpty) {
      MoaiSnackBar.showError(
        context,
        message:
            MoiamovApiService.instance.lastResolutionError ??
            LocaleKeys.movies_error_stream_connect.tr(),
        duration: const Duration(seconds: 4),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MoviePlayerScreen(
          movie: movie,
          stream: stream,
          initialPositionSeconds: startAt,
          saveProgress: saveProgress,
          series: series,
        ),
      ),
    );
  } catch (e) {
    MoiamovApiService.logLine('❌ Error al iniciar "${movie.name}": $e');
    if (context.mounted) {
      MoaiSnackBar.showError(
        context,
        message: LocaleKeys.movies_error_play_start.tr(),
        duration: const Duration(seconds: 4),
      );
    }
  }
}

/// Reproduce el capítulo de ahora de [playlist] (desde [startAt] si se
/// retoma) y sigue con los siguientes. Termina cuando se cierra el último
/// reproductor.
Future<void> playEpisode(
  BuildContext context,
  SeriesPlaylist playlist, {
  int? startAt,
}) async {
  await playMovie(
    context,
    playlist.item,
    startAt: startAt,
    series: playlist,
    resolveStream: (_) => playlist.resolveCurrent(),
  );
  if (playlist.started) await playlist.done;
}

/// Con algo visto, pregunta si retomar desde [positionSeconds] o empezar de
/// nuevo: `true` retomar, `false` desde el principio, `null` canceló.
Future<bool?> askResume(BuildContext context, int positionSeconds) {
  final fromStartFocus = FocusNode(debugLabel: 'resume_from_start');
  final resumeFocus = FocusNode(debugLabel: 'resume_resume');
  return showTvGeneralDialog<bool>(
    context: context,
    barrierLabel: 'ResumeOrRestart',
    builder: (dialogContext) => TvDialog(
      icon: MoaiIcons.vodResume,
      title: LocaleKeys.movies_resume_dialog_title.tr(),
      subtitle: LocaleKeys.movies_resume_dialog_desc.tr(
        namedArgs: {
          'time': formatPlayerTime(Duration(seconds: positionSeconds)),
        },
      ),
      actions: [
        TvDialogButton(
          label: LocaleKeys.movies_resume_from_start.tr(),
          focusNode: fromStartFocus,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          onKeyRight: resumeFocus.requestFocus,
        ),
        TvDialogButton(
          label: LocaleKeys.movies_resume.tr(),
          variant: TvDialogButtonVariant.primary,
          focusNode: resumeFocus,
          autofocus: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          onKeyLeft: fromStartFocus.requestFocus,
        ),
      ],
    ),
  ).whenComplete(() {
    fromStartFocus.dispose();
    resumeFocus.dispose();
  });
}
