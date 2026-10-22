import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de progreso de visualización de una película
class MovieWatchProgress {
  final String contentId;
  final int positionSeconds;
  final int totalDurationSeconds;
  final bool isCompleted;
  final int lastWatchedAt;

  const MovieWatchProgress({
    required this.contentId,
    required this.positionSeconds,
    required this.totalDurationSeconds,
    this.isCompleted = false,
    required this.lastWatchedAt,
  });

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'positionSeconds': positionSeconds,
    'totalDurationSeconds': totalDurationSeconds,
    'isCompleted': isCompleted,
    'lastWatchedAt': lastWatchedAt,
  };

  factory MovieWatchProgress.fromJson(Map<String, dynamic> json) {
    return MovieWatchProgress(
      contentId: json['contentId']?.toString() ?? '',
      positionSeconds: json['positionSeconds'] as int? ?? 0,
      totalDurationSeconds: json['totalDurationSeconds'] as int? ?? 0,
      isCompleted: json['isCompleted'] as bool? ?? false,
      lastWatchedAt: json['lastWatchedAt'] as int? ?? 0,
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

  static Future<void> saveProgress({
    required String contentId,
    required Duration currentPosition,
    required Duration totalDuration,
  }) async {
    final posSec = currentPosition.inSeconds;
    final totalSec = totalDuration.inSeconds;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Zona 1: Menos de 3 minutos (180s) -> No guardar progreso
    if (posSec < 180) {
      return;
    }

    // Zona 3: Últimos 5 minutos (300s) -> Marcar completado
    if (totalSec > 300 && posSec >= (totalSec - 300)) {
      final record = MovieWatchProgress(
        contentId: contentId,
        positionSeconds: 0,
        totalDurationSeconds: totalSec,
        isCompleted: true,
        lastWatchedAt: now,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$contentId', jsonEncode(record.toJson()));
      return;
    }

    // Zona 2: En progreso para reanudar
    final record = MovieWatchProgress(
      contentId: contentId,
      positionSeconds: posSec,
      totalDurationSeconds: totalSec,
      isCompleted: false,
      lastWatchedAt: now,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$contentId', jsonEncode(record.toJson()));
  }

  static Future<void> clearProgress(String contentId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$contentId');
  }
}
