import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';

/// Una película de "Seguir viendo" y cuánto se vio (0–1).
typedef ContinueWatchingEntry = ({MovieItem movie, double watched});

/// Reglas que unen el progreso ([MovieProgressService]) con Interesantes
/// ([MovieWatchlistService]). Una película está en un solo lugar:
/// Interesantes (sin empezar) → "Seguir viendo" (pasó los 3 min) → vista.
///
/// La interfaz (reproductor, Inicio) sólo llama a estas operaciones.
class MovieLibrary {
  const MovieLibrary._();

  /// Desde acá una película cuenta como empezada.
  static const startedAfter = Duration(minutes: 3);

  /// Guarda por dónde va [movie] según las zonas de [MovieProgressService].
  /// Pasados los 3 min sale de Interesantes: queda en "Seguir viendo" o
  /// vista. Antes no cuenta: una ya vista que se volvió a marcar como
  /// interesante sigue ahí aunque se abra un ratito.
  static Future<MovieWatchProgress?> recordProgress({
    required MovieItem movie,
    required Duration position,
    required Duration total,
  }) async {
    final saved = await MovieProgressService.saveProgress(
      contentId: movie.contentId,
      currentPosition: position,
      totalDuration: total,
      // Con la película, "Seguir viendo" la muestra sin esperar el catálogo.
      movie: movie,
    );
    if (saved != null && position >= startedAfter) {
      await MovieWatchlistService.instance.remove(movie.contentId);
    }
    return saved;
  }

  /// Las marca como vistas aunque hayan quedado a la mitad: salen de
  /// "Seguir viendo" y de Interesantes.
  static Future<void> markWatched(Iterable<MovieItem> movies) async {
    for (final movie in List.of(movies)) {
      await MovieProgressService.markWatched(movie.contentId);
      await MovieWatchlistService.instance.remove(movie.contentId);
    }
  }

  /// "Seguir viendo": las empezadas, la última vista primero. Los progresos
  /// guardados antes de que llevaran la película se buscan con [lookup] (el
  /// catálogo); sin ella no se muestran.
  ///
  /// También limpia Interesantes de las que quedaron en las dos de antes.
  static Future<List<ContinueWatchingEntry>> continueWatching({
    MovieItem? Function(String contentId)? lookup,
  }) async {
    final watchlist = MovieWatchlistService.instance;
    await watchlist.ensureLoaded();
    final entries = <ContinueWatchingEntry>[];
    for (final progress in await MovieProgressService.inProgress()) {
      if (watchlist.contains(progress.contentId)) {
        await watchlist.remove(progress.contentId);
      }
      final movie = progress.movie ?? lookup?.call(progress.contentId);
      if (movie == null) continue;
      entries.add((movie: movie, watched: progress.percentage));
    }
    return entries;
  }
}
