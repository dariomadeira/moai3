import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/movies/screens/movie_player_screen.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
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
          // Los adelantos se ven de una vez: sin progreso.
          saveProgress: !movie.isTrailer,
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
