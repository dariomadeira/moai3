import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un capítulo de una serie: temporada (su `contentId` y número) y su lugar
/// en ella.
class SeriesEpisodeRef {
  const SeriesEpisodeRef({
    required this.seasonId,
    required this.seasonNumber,
    required this.episodeIndex,
    required this.episodeNumber,
    this.episodeId = '',
  });

  final String seasonId;
  final int seasonNumber;
  final int episodeIndex;
  final int episodeNumber;

  /// `contentId` del capítulo (vacío si no se conocía, p. ej. el primero
  /// de una temporada que no se había pedido).
  final String episodeId;

  Map<String, dynamic> toJson() => {
    'seasonId': seasonId,
    'seasonNumber': seasonNumber,
    'episodeIndex': episodeIndex,
    'episodeNumber': episodeNumber,
    'episodeId': episodeId,
  };

  static SeriesEpisodeRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final seasonId = json['seasonId']?.toString() ?? '';
    if (seasonId.isEmpty) return null;
    return SeriesEpisodeRef(
      seasonId: seasonId,
      seasonNumber: json['seasonNumber'] as int? ?? 1,
      episodeIndex: json['episodeIndex'] as int? ?? 0,
      episodeNumber: json['episodeNumber'] as int? ?? 1,
      episodeId: json['episodeId']?.toString() ?? '',
    );
  }
}

/// Qué apareció de una serie que estaba al día (SPEC-46 §6.1).
enum SeriesContinueNews { episode, season }

/// Una serie que se está viendo ("Seguir series" del Inicio): el último
/// capítulo que se vio, cuál sigue y lo necesario para mostrarla y volver a
/// reproducirla sin el catálogo.
class SeriesContinueEntry {
  const SeriesContinueEntry({
    required this.seriesKey,
    required this.title,
    required this.seasons,
    required this.current,
    required this.episodeCount,
    required this.totalSeconds,
    required this.updatedAt,
    this.next,
    this.poster,
    this.backdrops = const [],
    this.plannedEpisodes,
    this.news,
    this.imdbId,
    this.continues,
    this.tmdbCheckedAt,
    this.seasonAirsAt,
  });

  /// La serie (el `contentId` de su primera temporada): una entrada por
  /// serie.
  final String seriesKey;
  final String title;
  final String? poster;
  final List<String> backdrops;

  /// Las temporadas (una por número, la versión elegida).
  final List<SeriesSeason> seasons;

  /// El último capítulo que se vio y cuántos tiene su temporada.
  final SeriesEpisodeRef current;
  final int episodeCount;
  final int totalSeconds;

  /// El que sigue; `null` si [current] era el último de la serie.
  final SeriesEpisodeRef? next;

  /// Cuándo se vio (segundos desde 1970): la más reciente primero.
  final int updatedAt;

  /// Cuántos capítulos va a tener la temporada de [current]
  /// ([SeriesSeasonDetail.plannedEpisodes]).
  final int? plannedEpisodes;

  /// [next] es un capítulo o una temporada que apareció después de que se
  /// quedó al día; `null` si es el que seguía nomás.
  final SeriesContinueNews? news;

  /// Id de IMDb de la serie ([SeriesSeasonDetail.imdbId]).
  final String? imdbId;

  /// Lo que dijo TMDb: la serie sigue (habrá más temporadas); `false` si
  /// terminó; `null` si todavía no se preguntó.
  final bool? continues;

  /// Cuándo se le preguntó a TMDb (segundos desde 1970).
  final int? tmdbCheckedAt;

  /// Cuándo sale la próxima temporada, si TMDb ya la anunció (segundos
  /// desde 1970): antes no se le pregunta al portal.
  final int? seasonAirsAt;

  /// Se vio el último capítulo subido y la temporada tiene más ("7 de 8").
  bool get awaitingEpisode =>
      next == null && (plannedEpisodes ?? 0) > current.episodeNumber;

  /// Se vio toda la serie subida, pero puede venir otra temporada: con id
  /// de IMDb y sin que TMDb diga que terminó.
  bool get awaitingSeason =>
      next == null && !awaitingEpisode && imdbId != null && continues != false;

  /// Al día sin terminar: no se muestra; se espera lo que falta
  /// ([SeriesContinueService.awaiting], SPEC-46 §6.1).
  bool get awaiting => awaitingEpisode || awaitingSeason;

  /// La misma, con lo que apareció ([next] y [news]) o, sin [next], sólo
  /// con el total de capítulos al día.
  SeriesContinueEntry withNews({
    SeriesEpisodeRef? next,
    SeriesContinueNews? news,
    int? plannedEpisodes,
    List<SeriesSeason>? seasons,
    int? updatedAt,
    bool? continues,
    int? tmdbCheckedAt,
    int? seasonAirsAt,
  }) => SeriesContinueEntry(
    seriesKey: seriesKey,
    title: title,
    poster: poster,
    backdrops: backdrops,
    seasons: seasons ?? this.seasons,
    current: current,
    next: next ?? this.next,
    episodeCount: episodeCount,
    totalSeconds: totalSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
    plannedEpisodes: plannedEpisodes ?? this.plannedEpisodes,
    news: news ?? this.news,
    imdbId: imdbId,
    continues: continues ?? this.continues,
    tmdbCheckedAt: tmdbCheckedAt ?? this.tmdbCheckedAt,
    seasonAirsAt: seasonAirsAt ?? this.seasonAirsAt,
  );

  Map<String, dynamic> toJson() => {
    'seriesKey': seriesKey,
    'title': title,
    'poster': poster,
    'backdrops': backdrops,
    'seasons': [
      for (final s in seasons) {'contentId': s.contentId, 'number': s.number},
    ],
    'current': current.toJson(),
    'next': next?.toJson(),
    'episodeCount': episodeCount,
    'totalSeconds': totalSeconds,
    'updatedAt': updatedAt,
    'plannedEpisodes': plannedEpisodes,
    'news': news?.name,
    'imdbId': imdbId,
    'continues': continues,
    'tmdbCheckedAt': tmdbCheckedAt,
    'seasonAirsAt': seasonAirsAt,
  };

  static SeriesContinueEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['seriesKey']?.toString() ?? '';
    final current = SeriesEpisodeRef.fromJson(json['current']);
    if (key.isEmpty || current == null) return null;
    return SeriesContinueEntry(
      seriesKey: key,
      title: json['title']?.toString() ?? '',
      poster: json['poster']?.toString(),
      backdrops: [for (final b in (json['backdrops'] as List?) ?? []) '$b'],
      seasons: [
        for (final s in (json['seasons'] as List?) ?? [])
          if (s is Map && s['contentId'] != null)
            SeriesSeason(
              contentId: '${s['contentId']}',
              number: s['number'] as int? ?? 1,
            ),
      ],
      current: current,
      next: SeriesEpisodeRef.fromJson(json['next']),
      episodeCount: json['episodeCount'] as int? ?? 0,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      plannedEpisodes: json['plannedEpisodes'] as int?,
      news: SeriesContinueNews.values
          .where((n) => n.name == json['news'])
          .firstOrNull,
      imdbId: json['imdbId'] as String?,
      continues: json['continues'] as bool?,
      tmdbCheckedAt: json['tmdbCheckedAt'] as int?,
      seasonAirsAt: json['seasonAirsAt'] as int?,
    );
  }
}

/// Lo que muestra "Seguir series" de una serie: el capítulo a ver (el que
/// quedó a la mitad o, si se terminó, el siguiente).
class SeriesContinueItem {
  const SeriesContinueItem({
    required this.entry,
    required this.episode,
    required this.isNext,
    this.resumeAt,
  });

  final SeriesContinueEntry entry;
  final SeriesEpisodeRef episode;

  /// Es el siguiente al último que se vio (sin empezar).
  final bool isNext;

  /// Dónde retomarlo (a la mitad).
  final Duration? resumeAt;

  /// Cuánto se vio (0–1) para la barra; sin dato, `null`.
  double? get progress {
    final at = resumeAt;
    final total = entry.totalSeconds;
    if (at == null || total <= 0) return null;
    return (at.inSeconds / total).clamp(0.0, 1.0);
  }
}

/// "Seguir series" del Inicio: las series que se están viendo, la última
/// primero. La lleva el reproductor ([record]) cada vez que guarda lo visto
/// de un capítulo (pasados los primeros minutos, como el resto).
class SeriesContinueService {
  static const String _key = 'series_continue_v1';

  /// Cambió algo de lo que muestra la tarjeta (una serie anotada o
  /// quitada, o lo visto): el Inicio la vuelve a leer. Si no, al volver de
  /// Series seguía mostrando lo de antes.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  static void notifyChanged() => changes.value++;

  /// Cuántas series se recuerdan: las más viejas se olvidan.
  static const int maxSeries = 30;

  /// Cuánto se espera lo que falta de una serie al día: después se olvida.
  static const Duration awaitFor = Duration(days: 180);

  /// Una temporada nueva que TMDb confirma tarda más (suele ser un año o
  /// dos).
  static const Duration awaitSeasonFor = Duration(days: 730);

  static bool _expired(SeriesContinueEntry entry, DateTime now) =>
      now.millisecondsSinceEpoch ~/ 1000 - entry.updatedAt >
      (entry.continues == true ? awaitSeasonFor : awaitFor).inSeconds;

  /// Las series al día que esperan un capítulo ([SeriesContinueEntry.
  /// awaiting]) y no vencieron.
  static Future<List<SeriesContinueEntry>> awaiting({DateTime? now}) async => [
    for (final e in await entries())
      if (e.awaiting && !_expired(e, now ?? DateTime.now())) e,
  ];

  /// Reemplaza la entrada de su serie (si todavía está: si se quitó a mano
  /// mientras tanto, no vuelve).
  static Future<void> replace(SeriesContinueEntry entry) async {
    final list = await entries();
    if (!list.any((e) => e.seriesKey == entry.seriesKey)) return;
    await _write([
      for (final e in list) e.seriesKey == entry.seriesKey ? entry : e,
    ]);
  }

  static Future<List<SeriesContinueEntry>> entries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const [];
      final json = jsonDecode(raw);
      if (json is! List) return const [];
      return [for (final e in json) ?SeriesContinueEntry.fromJson(e)]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return const [];
    }
  }

  /// Anota (o actualiza) la serie de [entry] como la última vista. Como en
  /// películas, una serie empezada sale de "Series marcadas".
  static Future<void> record(SeriesContinueEntry entry) async {
    await SeriesWatchlistService.instance.remove({
      for (final s in entry.seasons) s.contentId,
      entry.current.seasonId,
    });
    final list = [
      entry,
      for (final e in await entries())
        if (e.seriesKey != entry.seriesKey) e,
    ];
    await _write(list.take(maxSeries).toList());
  }

  /// Mantener OK en la tarjeta: la serie sale (lo visto queda marcado).
  static Future<void> remove(String seriesKey) async {
    await _write([
      for (final e in await entries())
        if (e.seriesKey != seriesKey) e,
    ]);
  }

  static Future<void> clear() => _write(const []);

  /// Lo que muestra la tarjeta, según lo visto: el último capítulo si quedó
  /// a la mitad o, si se terminó (o se marcó como visto), el siguiente. Las
  /// series terminadas no salen (y se olvidan); las que esperan un capítulo
  /// ([SeriesContinueEntry.awaiting]) no salen pero se recuerdan.
  static Future<List<SeriesContinueItem>> items({DateTime? now}) async {
    final items = <SeriesContinueItem>[];
    final finished = <String>[];
    for (final entry in await entries()) {
      final current = entry.current;
      final watch = await SeriesWatchService.season(current.seasonId);
      if (!watch.watched.contains(current.episodeId)) {
        items.add(
          SeriesContinueItem(
            entry: entry,
            episode: current,
            isNext: false,
            resumeAt: await SeriesWatchService.resumeAt(current.episodeId),
          ),
        );
      } else if (entry.next case final next?) {
        items.add(
          SeriesContinueItem(entry: entry, episode: next, isNext: true),
        );
      } else if (!entry.awaiting || _expired(entry, now ?? DateTime.now())) {
        finished.add(entry.seriesKey);
      }
    }
    for (final key in finished) {
      await remove(key);
    }
    return items;
  }

  static Future<void> _write(List<SeriesContinueEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final e in list) e.toJson()]));
    notifyChanged();
  }
}
