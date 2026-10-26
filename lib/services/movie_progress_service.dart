import 'dart:convert';
import 'package:moai3/models/movie_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de progreso de visualización de una película
class MovieWatchProgress {
  final String contentId;
  final int positionSeconds;
  final int totalDurationSeconds;
  final bool isCompleted;
  final int lastWatchedAt;

  /// La película, para mostrarla en "Seguir viendo" sin esperar el catálogo.
  /// Los progresos guardados antes no la tienen.
  final MovieItem? movie;

  const MovieWatchProgress({
    required this.contentId,
    required this.positionSeconds,
    required this.totalDurationSeconds,
    this.isCompleted = false,
    required this.lastWatchedAt,
    this.movie,
  });

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'positionSeconds': positionSeconds,
    'totalDurationSeconds': totalDurationSeconds,
    'isCompleted': isCompleted,
    'lastWatchedAt': lastWatchedAt,
    if (movie != null) 'movie': movie!.toJson(),
  };

  factory MovieWatchProgress.fromJson(Map<String, dynamic> json) {
    final movie = json['movie'];
    return MovieWatchProgress(
      contentId: json['contentId']?.toString() ?? '',
      positionSeconds: json['positionSeconds'] as int? ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      lastWatchedAt: json['lastWatchedAt'] as int? ?? 0,
      movie: movie is Map<String, dynamic> ? MovieItem.fromJson(movie) : null,
    );
  }

  /// Porcentaje de progreso de 0.0 a 1.0
  double get percentage {
    if (totalDurationSeconds <= 0) return 0.0;
    return (positionSeconds / totalDurationSeconds).clamp(0.0, 1.0);
  }

  /// Porcentaje de progreso de 0.0 a 1.0 (alias)
  double get progressPercentage => percentage;

  /// Indica si la película está en la Zona 2 y puede reanudarse
  bool get canResume => !isCompleted && positionSeconds > 180;
}

/// Servicio que gestiona la persistencia de progreso según la regla de 3 zonas del PLAN:
/// - Zona 1 (0 - 3 min): No se marca progreso.
/// - Zona 2 (> 3 min hasta 5 min antes del final): Se marca progreso para retomar.
/// - Zona 3 (últimos 5 minutos): Se marca como completado/visto.
class MovieProgressService {
  static const String _prefix = 'movie_progress_';

  /// Cuántas vistas se recuerdan: las más viejas se olvidan (todo el
  /// progreso se carga en memoria al arrancar).
  static const int maxWatched = 300;

  static Future<MovieWatchProgress?> getProgress(String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$contentId');
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return MovieWatchProgress.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  /// Las películas empezadas que se pueden retomar ("Seguir viendo"), la
  /// última vista primero.
  static Future<List<MovieWatchProgress>> inProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <MovieWatchProgress>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final progress = await getProgress(key.substring(_prefix.length));
      if (progress != null && progress.canResume) list.add(progress);
    }
    list.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
    return list;
  }

  /// Guarda según la zona y devuelve cómo quedó (`null`: sin progreso).
  /// Con [movie], el registro la guarda para "Seguir viendo".
  static Future<MovieWatchProgress?> saveProgress({
    required String contentId,
    required Duration currentPosition,
    required Duration totalDuration,
    MovieItem? movie,
  }) async {
    final posSec = currentPosition.inSeconds;
    final totalSec = totalDuration.inSeconds;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Zona 1: Menos de 3 minutos (180s) -> No cuenta: no se marca nada ni se
    // toca lo que había. Si se volvió a empezar desde el principio y se salió
    // enseguida, sigue el punto viejo (y en "Seguir viendo"); una ya vista
    // sigue vista.
    if (posSec < 180) return getProgress(contentId);

    // Zona 3: Últimos 5 minutos (300s) -> Marcar completado (sin la
    // película: sólo "Seguir viendo" la necesita).
    if (totalSec > 300 && posSec >= (totalSec - 300)) {
      return _writeWatched(
        MovieWatchProgress(
          contentId: contentId,
          positionSeconds: 0,
          totalDurationSeconds: totalSec,
          isCompleted: true,
          lastWatchedAt: now,
        ),
      );
    }

    // Zona 2: En progreso para reanudar
    return _write(
      MovieWatchProgress(
        contentId: contentId,
        positionSeconds: posSec,
        totalDurationSeconds: totalSec,
        lastWatchedAt: now,
        movie: movie,
      ),
    );
  }

  /// La marca como vista aunque haya quedado a la mitad ("Seguir viendo").
  static Future<MovieWatchProgress> markWatched(String contentId) async {
    final previous = await getProgress(contentId);
    return _writeWatched(
      MovieWatchProgress(
        contentId: contentId,
        positionSeconds: 0,
        totalDurationSeconds: previous?.totalDurationSeconds ?? 0,
        isCompleted: true,
        lastWatchedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ),
    );
  }

  /// Guarda una vista y olvida las más viejas pasado [maxWatched].
  static Future<MovieWatchProgress> _writeWatched(
    MovieWatchProgress record,
  ) async {
    await _write(record);
    final prefs = await SharedPreferences.getInstance();
    final watched = <MovieWatchProgress>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final progress = await getProgress(key.substring(_prefix.length));
      if (progress != null && progress.isCompleted) watched.add(progress);
    }
    if (watched.length > maxWatched) {
      watched.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));
      for (final old in watched.skip(maxWatched)) {
        await prefs.remove('$_prefix${old.contentId}');
      }
    }
    return record;
  }

  static Future<MovieWatchProgress> _write(MovieWatchProgress record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${record.contentId}',
      jsonEncode(record.toJson()),
    );
    return record;
  }

  static Future<void> clearProgress(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$contentId');
  }
}
