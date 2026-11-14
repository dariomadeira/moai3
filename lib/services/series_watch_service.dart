import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lo visto de una temporada: los capítulos vistos y cuántos tiene.
class SeriesSeasonWatch {
  const SeriesSeasonWatch({this.watched = const {}, this.episodeCount = 0});

  /// `contentId` de los capítulos vistos.
  final Set<String> watched;

  /// Cuántos capítulos tiene (0: no se sabe todavía).
  final int episodeCount;

  /// Todos sus capítulos vistos.
  bool get complete => episodeCount > 0 && watched.length >= episodeCount;

  Map<String, dynamic> toJson() => {
    'watched': watched.toList(),
    'count': episodeCount,
  };

  factory SeriesSeasonWatch.fromJson(Map<String, dynamic> json) =>
      SeriesSeasonWatch(
        watched: {
          for (final id in (json['watched'] as List?) ?? const []) '$id',
        },
        episodeCount: json['count'] as int? ?? 0,
      );
}

/// Lo visto de las series, aparte de las películas (una serie larga llenaría
/// el tope de [MovieProgressService]): por temporada, los capítulos vistos;
/// por capítulo, dónde retomarlo.
///
/// Reglas (las de películas, con otro final):
/// - Menos de [startedAfter] no cuenta: no se toca nada.
/// - Desde [endsBefore] antes del final, el capítulo queda visto.
/// - En el medio se guarda dónde retomar.
class SeriesWatchService {
  static const String _seasonPrefix = 'series_season_';
  static const String _resumePrefix = 'series_resume_';

  static const Duration startedAfter = Duration(minutes: 3);
  static const Duration endsBefore = Duration(minutes: 3);

  static Future<SeriesSeasonWatch> season(String seasonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_seasonPrefix$seasonId');
      if (raw != null) {
        final json = jsonDecode(raw);
        if (json is Map<String, dynamic>) {
          return SeriesSeasonWatch.fromJson(json);
        }
      }
    } catch (e) {
      // Guardado ilegible: como si no se hubiera visto nada.
      debugPrint('[SeriesWatch] Temporada ilegible $seasonId: $e');
    }
    return const SeriesSeasonWatch();
  }

  /// Anota cuántos capítulos tiene: así la temporada sabe si está completa
  /// aunque no se abra.
  static Future<void> rememberEpisodeCount(String seasonId, int count) async {
    final current = await season(seasonId);
    if (count <= 0 || current.episodeCount == count) return;
    await _writeSeason(
      seasonId,
      SeriesSeasonWatch(watched: current.watched, episodeCount: count),
    );
  }

  /// Las temporadas con todos sus capítulos (los que se conocían) vistos.
  static Future<List<String>> completedSeasonIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <String>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_seasonPrefix)) continue;
      final id = key.substring(_seasonPrefix.length);
      final watch = await season(id);
      if (watch.episodeCount > 0 &&
          watch.watched.length >= watch.episodeCount) {
        ids.add(id);
      }
    }
    return ids;
  }

  /// Dónde retomar el capítulo; `null` si no hay (no empezado o visto).
  static Future<Duration?> resumeAt(String episodeId) async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt('$_resumePrefix$episodeId');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// Guarda por dónde va el capítulo [episodeId] de la temporada [seasonId]
  /// (que tiene [episodeCount] capítulos), según las reglas de arriba.
  static Future<void> recordProgress({
    required String seasonId,
    required String episodeId,
    required int episodeCount,
    required Duration position,
    required Duration total,
  }) async {
    if (position < startedAfter || total <= Duration.zero) return;
    final prefs = await SharedPreferences.getInstance();
    if (total > endsBefore && position >= total - endsBefore) {
      await prefs.remove('$_resumePrefix$episodeId');
      final current = await season(seasonId);
      await _writeSeason(
        seasonId,
        SeriesSeasonWatch(
          watched: {...current.watched, episodeId},
          episodeCount: episodeCount > 0 ? episodeCount : current.episodeCount,
        ),
      );
      return;
    }
    await prefs.setInt('$_resumePrefix$episodeId', position.inSeconds);
  }

  /// Marca a mano los capítulos [episodeIds] de la temporada como vistos (o
  /// les saca la marca con [watched] en falso). Visto ya no se retoma.
  static Future<void> setWatched({
    required String seasonId,
    required Iterable<String> episodeIds,
    required bool watched,
    required int episodeCount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await season(seasonId);
    final ids = {...current.watched};
    for (final id in episodeIds) {
      if (watched) {
        ids.add(id);
        await prefs.remove('$_resumePrefix$id');
      } else {
        ids.remove(id);
      }
    }
    await _writeSeason(
      seasonId,
      SeriesSeasonWatch(
        watched: ids,
        episodeCount: episodeCount > 0 ? episodeCount : current.episodeCount,
      ),
    );
  }

  /// Ajustes › Películas y series: borra todos los capítulos vistos y por
  /// dónde iba cada uno ("Seguir series" lo borra
  /// [SeriesContinueService.clear]).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_seasonPrefix) || key.startsWith(_resumePrefix)) {
        await prefs.remove(key);
      }
    }
    SeriesContinueService.notifyChanged();
  }

  static Future<void> _writeSeason(
    String seasonId,
    SeriesSeasonWatch watch,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_seasonPrefix$seasonId',
      jsonEncode(watch.toJson()),
    );
    // Lo visto cambia qué capítulo muestra "Seguir series".
    SeriesContinueService.notifyChanged();
  }
}
