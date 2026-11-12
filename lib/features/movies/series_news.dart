import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/services/tmdb_series_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Capítulos y temporadas nuevas de las series al día (SPEC-46 §6.1).
///
/// Una serie de la que se vio el último capítulo subido, con la temporada
/// sin terminar ("7 de 8", [SeriesContinueEntry.awaiting]), no se olvida:
/// una vez por día se le pregunta al portal por esa temporada y, si
/// apareció el capítulo que faltaba (o una temporada nueva), vuelve a
/// "Seguir series" con ese capítulo y la etiqueta de nuevo.
///
/// Con toda la serie vista (temporada completa y sin otra), se le pregunta
/// a TMDb por su id de IMDb si sigue: si terminó se olvida; si sigue, se
/// espera la temporada nueva (sin preguntarle al portal antes de la fecha
/// que anuncie TMDb).
class SeriesNews {
  SeriesNews._();

  static const String _checkedKey = 'series_news_checked_at';
  static const String _rescuedKey = 'series_news_rescued_v2';

  /// Cada cuánto se le vuelve a preguntar a TMDb por una serie (una que
  /// seguía puede terminar).
  static const Duration tmdbEvery = Duration(days: 30);

  /// Cada cuánto se pregunta.
  static const Duration every = Duration(days: 1);

  /// Cuántas temporadas se piden como mucho en el rescate.
  static const int maxRescue = 25;

  static Future<void>? _running;

  /// Revisa (si pasó [every] desde la última vez). Lo llama el Inicio
  /// cuando ya hay sesión en el portal. Devuelve si cambió algo.
  static Future<bool> check({
    Future<SeriesSeasonDetail?> Function(String contentId)? fetchSeason,
    TmdbSeriesService? tmdb,
    DateTime? now,
  }) async {
    if (_running != null) {
      await _running;
      return false;
    }
    final done = Completer<bool>();
    _running = done.future;
    try {
      final changed = await _check(
        fetchSeason ?? MoiamovApiService.instance.fetchSeriesSeason,
        tmdb ?? TmdbSeriesService(),
        now ?? DateTime.now(),
      );
      done.complete(changed);
      return changed;
    } catch (e) {
      debugPrint('⚠️ [SeriesNews] $e');
      done.complete(false);
      return false;
    } finally {
      _running = null;
    }
  }

  static Future<bool> _check(
    Future<SeriesSeasonDetail?> Function(String contentId) fetch,
    TmdbSeriesService tmdb,
    DateTime now,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_checkedKey);
    if (last != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < every) {
      return false;
    }
    var asked = 0;
    var answered = 0;
    var changed = false;

    // Una sola vez: las series al día de antes de esto ya se habían
    // olvidado; se buscan por las temporadas que tienen todo visto.
    if (!(prefs.getBool(_rescuedKey) ?? false)) {
      final (a, b) = await _rescue(fetch);
      asked += a;
      answered += b;
      if (a == 0 || b > 0) await prefs.setBool(_rescuedKey, true);
    }

    final stamp = now.millisecondsSinceEpoch ~/ 1000;
    for (var entry in await SeriesContinueService.awaiting(now: now)) {
      if (entry.awaitingSeason && _tmdbDue(entry, stamp)) {
        final status = await tmdb.statusOf(entry.imdbId!);
        if (status != null) {
          entry = withStatus(entry, status, now);
          await SeriesContinueService.replace(entry);
          // Terminó: la tarjeta la olvida.
          if (!entry.awaiting) continue;
        }
      }
      // La temporada nueva tiene fecha y todavía no salió.
      if (entry.awaitingSeason && (entry.seasonAirsAt ?? 0) > stamp) continue;
      asked++;
      final detail = await fetch(entry.current.seasonId);
      if (detail == null) continue;
      answered++;
      final updated = news(entry, detail, now);
      if (updated == null) continue;
      await SeriesContinueService.replace(updated);
      changed = true;
    }
    // Sin sesión todavía no contestó nadie: se vuelve a probar la próxima.
    if (asked == 0 || answered > 0) {
      await prefs.setInt(_checkedKey, now.millisecondsSinceEpoch);
    }
    return changed;
  }

  static bool _tmdbDue(SeriesContinueEntry entry, int stamp) =>
      entry.tmdbCheckedAt == null ||
      stamp - entry.tmdbCheckedAt! > tmdbEvery.inSeconds;

  /// [entry] con lo que dijo TMDb: sigue si está en emisión o si tiene más
  /// temporadas que la vista (el portal todavía no la subió); y cuándo sale
  /// la próxima, si ya está anunciada.
  @visibleForTesting
  static SeriesContinueEntry withStatus(
    SeriesContinueEntry entry,
    TmdbSeriesStatus status,
    DateTime now,
  ) {
    final season = entry.current.seasonNumber;
    final airs = status.nextAirDate;
    return entry.withNews(
      continues: status.continues || status.seasons > season,
      tmdbCheckedAt: now.millisecondsSinceEpoch ~/ 1000,
      seasonAirsAt: airs != null && (status.nextSeason ?? 0) > season
          ? airs.millisecondsSinceEpoch ~/ 1000
          : 0,
    );
  }

  /// [entry] con lo que apareció en [detail] (la temporada que esperaba):
  /// el capítulo que sigue al último visto o, si no, el primero de una
  /// temporada nueva. Sin novedades, con el total al día si cambió; `null`
  /// si no hay nada que cambiar.
  @visibleForTesting
  static SeriesContinueEntry? news(
    SeriesContinueEntry entry,
    SeriesSeasonDetail detail,
    DateTime now,
  ) {
    final current = entry.current;
    final stamp = now.millisecondsSinceEpoch ~/ 1000;
    final episodes = detail.episodes;
    final index = episodes.indexWhere((e) => e.number > current.episodeNumber);
    if (index >= 0) {
      final episode = episodes[index];
      return entry.withNews(
        next: SeriesEpisodeRef(
          seasonId: current.seasonId,
          seasonNumber: current.seasonNumber,
          episodeIndex: index,
          episodeNumber: episode.number,
          episodeId: episode.contentId,
        ),
        news: SeriesContinueNews.episode,
        plannedEpisodes: detail.plannedEpisodes,
        // Primera en la tarjeta: es lo último que pasó.
        updatedAt: stamp,
      );
    }
    final seasons = SeriesSeasonDetail.bestSeasons(detail.seasons, {
      current.seasonId: detail,
    });
    final later = seasons
        .where((s) => s.number > current.seasonNumber)
        .firstOrNull;
    if (later != null) {
      return entry.withNews(
        next: SeriesEpisodeRef(
          seasonId: later.contentId,
          seasonNumber: later.number,
          episodeIndex: 0,
          episodeNumber: 1,
        ),
        news: SeriesContinueNews.season,
        seasons: seasons,
        plannedEpisodes: detail.plannedEpisodes,
        updatedAt: stamp,
      );
    }
    if (detail.plannedEpisodes == entry.plannedEpisodes) return null;
    // El total cambió (p. ej. ya no faltan): si deja de esperar, la
    // tarjeta la olvida.
    return entry.withNews(plannedEpisodes: detail.plannedEpisodes ?? 0);
  }

  /// Las temporadas con todo visto que no están en "Seguir series": si la
  /// temporada es la última de la serie y le faltan capítulos (o tiene id de
  /// IMDb: puede venir otra temporada), la serie entra como al día
  /// ([SeriesContinueEntry.awaiting]). Devuelve cuántas se pidieron y
  /// cuántas contestaron.
  static Future<(int, int)> _rescue(
    Future<SeriesSeasonDetail?> Function(String contentId) fetch,
  ) async {
    final known = <String>{
      for (final e in await SeriesContinueService.entries()) ...[
        e.current.seasonId,
        for (final s in e.seasons) s.contentId,
      ],
    };
    final ids = [
      for (final id in await SeriesWatchService.completedSeasonIds())
        if (!known.contains(id)) id,
    ].take(maxRescue);
    var asked = 0;
    var answered = 0;
    for (final id in ids) {
      asked++;
      final detail = await fetch(id);
      if (detail == null || detail.episodes.isEmpty) continue;
      answered++;
      final last = detail.episodes.last;
      // Le faltan capítulos o, con id de IMDb, puede venir otra temporada
      // (TMDb decide en la revisión).
      if (!detail.expectsAfter(last.number) && detail.imdbId == null) {
        continue;
      }
      final seasons = SeriesSeasonDetail.bestSeasons(detail.seasons, {
        id: detail,
      });
      final number = seasons
          .where((s) => s.contentId == id)
          .firstOrNull
          ?.number;
      // Sólo si es la última: si hay otra después, no está al día.
      if (number == null || seasons.any((s) => s.number > number)) continue;
      final entry = SeriesPlaylist(
        seasons: seasons,
        details: {id: detail},
        startSeasonId: id,
        startEpisodeIndex: detail.episodes.length - 1,
      ).continueEntry(Duration.zero);
      await SeriesContinueService.record(entry);
    }
    return (asked, answered);
  }
}
