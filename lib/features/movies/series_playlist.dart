import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';

/// El capítulo siguiente, listo para el reproductor.
class PlayerNext {
  const PlayerNext(this.movie, this.stream);

  final MovieItem movie;
  final ResolvedPlayStream stream;
}

/// Pide el video de un capítulo ([item] es el capítulo como película).
typedef EpisodeStreamResolver =
    Future<ResolvedPlayStream?> Function(
      MovieItem season,
      SeriesEpisode episode,
      MovieItem item,
    );

/// Lo que se está viendo de una serie: la temporada y el capítulo, y cuál
/// sigue. Al terminar un capítulo el reproductor pide [next]: el siguiente
/// de la temporada o, al final, el primero de la próxima; después de la
/// última no hay más.
class SeriesPlaylist {
  SeriesPlaylist({
    required this.seasons,
    required Map<String, SeriesSeasonDetail> details,
    required String startSeasonId,
    required int startEpisodeIndex,
    Future<SeriesSeasonDetail?> Function(String contentId)? fetchSeason,
    EpisodeStreamResolver? resolveStream,
    this.onStarted,
    String? recommendationKey,
  }) : _givenRecommendationKey = recommendationKey,
       _details = {...details},
       _seasonId = startSeasonId,
       _episodeIndex = startEpisodeIndex,
       _fetchSeason =
           fetchSeason ?? MoiamovApiService.instance.fetchSeriesSeason,
       _resolve =
           resolveStream ??
           ((season, episode, item) =>
               MoiamovApiService.instance.resolveEpisodeStream(
                 season: season,
                 episode: episode,
                 item: item,
               ));

  /// Las temporadas de la serie, ordenadas.
  final List<SeriesSeason> seasons;
  final Map<String, SeriesSeasonDetail> _details;
  final Future<SeriesSeasonDetail?> Function(String contentId) _fetchSeason;
  final EpisodeStreamResolver _resolve;

  String _seasonId;
  int _episodeIndex;

  /// La temporada y el capítulo que se están viendo (al volver al detalle,
  /// el último que se vio).
  String get seasonId => _seasonId;
  int get episodeIndex => _episodeIndex;

  /// Las temporadas pedidas (también las que se pidieron al pasar de una a
  /// otra).
  Map<String, SeriesSeasonDetail> get details => Map.unmodifiable(_details);

  SeriesSeasonDetail get _detail => _details[_seasonId]!;
  SeriesEpisode get episode => _detail.episodes[_episodeIndex];

  int _numberOf(String seasonId) =>
      seasons.where((s) => s.contentId == seasonId).firstOrNull?.number ??
      SeriesSeasonDetail.seasonNumber(_details[seasonId]!.info) ??
      1;

  /// El capítulo de ahora como película, para el reproductor.
  MovieItem get item =>
      episodeItem(_detail.info, _numberOf(_seasonId), episode);

  /// La serie para recomendar (la misma en todos los TV; la calcula el
  /// detalle, que conoce todas las versiones de las temporadas).
  final String? _givenRecommendationKey;

  String get recommendationKey =>
      _givenRecommendationKey ??
      SeriesSeasonDetail.recommendationKey(seasons, _seasonId);

  /// El número de la temporada de ahora.
  int get seasonNumber => _numberOf(_seasonId);

  /// Es el último capítulo de su temporada: al terminarlo se pregunta si
  /// recomendar la serie.
  bool get isLastOfSeason => _episodeIndex == _detail.episodes.length - 1;

  /// La serie como película, para recomendarla.
  MovieItem get recommendationItem {
    final key = recommendationKey;
    final info = _details[key]?.info ?? _detail.info;
    return MovieItem(
      contentId: key,
      name: SeriesSeasonDetail.seriesTitle(info.name),
      poster: info.poster,
      backdrop: info.backdrop,
      backdrops: info.backdrops,
      year: info.year,
      score: info.score,
      programType: 'teleplay',
    );
  }

  /// Pide el video del capítulo de ahora.
  Future<ResolvedPlayStream?> resolveCurrent() =>
      _resolve(_detail.info, episode, item);

  /// El audio elegido a mano vale para toda la serie: se guarda con la
  /// primera temporada.
  String get audioKey =>
      'series:${seasons.firstOrNull?.contentId ?? _seasonId}';

  int get _seasonPosition =>
      seasons.indexWhere((s) => s.contentId == _seasonId);

  /// Qué sigue, para el aviso ("Siguiente: Capítulo 6"); `null` si era el
  /// último.
  String? get nextLabel {
    if (_episodeIndex + 1 < _detail.episodes.length) {
      return LocaleKeys.series_next_episode.tr(
        namedArgs: {'episode': '${_detail.episodes[_episodeIndex + 1].number}'},
      );
    }
    final position = _seasonPosition;
    if (position < 0 || position + 1 >= seasons.length) return null;
    return LocaleKeys.series_next_season.tr(
      namedArgs: {'season': '${seasons[position + 1].number}'},
    );
  }

  /// Por qué no se pudo pasar al siguiente (para el aviso).
  String? lastError;

  /// Pide el video del capítulo siguiente y pasa a él; `null` si no hay
  /// más o no se pudo (ver [lastError]).
  Future<PlayerNext?> next() async {
    lastError = null;
    var seasonId = _seasonId;
    var index = _episodeIndex + 1;
    if (index >= _detail.episodes.length) {
      final position = _seasonPosition;
      if (position < 0 || position + 1 >= seasons.length) return null;
      seasonId = seasons[position + 1].contentId;
      index = 0;
      final detail = _details[seasonId] ?? await _fetchSeason(seasonId);
      if (detail == null || detail.episodes.isEmpty) {
        lastError = LocaleKeys.series_episodes_error.tr();
        return null;
      }
      _details[seasonId] = detail;
      unawaited(
        SeriesWatchService.rememberEpisodeCount(
          seasonId,
          detail.episodes.length,
        ),
      );
    }
    final detail = _details[seasonId]!;
    final episode = detail.episodes[index];
    final item = episodeItem(detail.info, _numberOf(seasonId), episode);
    final stream = await _resolve(detail.info, episode, item);
    if (stream == null || stream.directHlsUrl.isEmpty) {
      lastError =
          MoiamovApiService.instance.lastResolutionError ??
          LocaleKeys.movies_error_stream_connect.tr();
      return null;
    }
    _seasonId = seasonId;
    _episodeIndex = index;
    return PlayerNext(item, stream);
  }

  /// Guarda por dónde va el capítulo de ahora y, pasados los primeros
  /// minutos, anota la serie en "Seguir series" del Inicio.
  Future<void> record(Duration position, Duration total) async {
    await SeriesWatchService.recordProgress(
      seasonId: _seasonId,
      episodeId: episode.contentId,
      episodeCount: _detail.episodes.length,
      position: position,
      total: total,
    );
    if (position < SeriesWatchService.startedAfter) return;
    await SeriesContinueService.record(continueEntry(total));
  }

  /// La serie para "Seguir series": el capítulo de ahora y el siguiente
  /// (también lo usa el detalle al marcar a mano).
  SeriesContinueEntry continueEntry(Duration total) {
    final info = _detail.info;
    return SeriesContinueEntry(
      seriesKey: audioKey,
      title: SeriesSeasonDetail.seriesTitle(info.name),
      poster: info.poster,
      backdrops: [
        if (info.backdrop case final b? when b.isNotEmpty) b,
        ...info.backdrops,
      ],
      seasons: seasons,
      current: SeriesEpisodeRef(
        seasonId: _seasonId,
        seasonNumber: _numberOf(_seasonId),
        episodeIndex: _episodeIndex,
        episodeNumber: episode.number,
        episodeId: episode.contentId,
      ),
      next: _nextRef(),
      episodeCount: _detail.episodes.length,
      totalSeconds: total.inSeconds,
      updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
  }

  /// El capítulo que sigue al de ahora (sin pedir nada): en la temporada o,
  /// al final, el primero de la próxima; `null` después del último.
  SeriesEpisodeRef? _nextRef() {
    final episodes = _detail.episodes;
    if (_episodeIndex + 1 < episodes.length) {
      final next = episodes[_episodeIndex + 1];
      return SeriesEpisodeRef(
        seasonId: _seasonId,
        seasonNumber: _numberOf(_seasonId),
        episodeIndex: _episodeIndex + 1,
        episodeNumber: next.number,
        episodeId: next.contentId,
      );
    }
    final position = _seasonPosition;
    if (position < 0 || position + 1 >= seasons.length) return null;
    final season = seasons[position + 1];
    final first = _details[season.contentId]?.episodes.firstOrNull;
    return SeriesEpisodeRef(
      seasonId: season.contentId,
      seasonNumber: season.number,
      episodeIndex: 0,
      episodeNumber: first?.number ?? 1,
      episodeId: first?.contentId ?? '',
    );
  }

  bool _started = false;
  final Completer<void> _done = Completer<void>();

  /// Ya se abrió el reproductor.
  bool get started => _started;

  /// Termina cuando se cierra el último reproductor de la serie.
  Future<void> get done => _done.future;

  /// Se abrió el primer reproductor (el detalle saca la ruedita).
  final VoidCallback? onStarted;

  void markStarted() {
    if (_started) return;
    _started = true;
    onStarted?.call();
  }

  void close() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// El capítulo [episode] de la temporada [season] (número [seasonNumber])
/// como película: el reproductor lo muestra como "Serie · T2 · Capítulo 5".
MovieItem episodeItem(
  MovieItem season,
  int seasonNumber,
  SeriesEpisode episode,
) => MovieItem(
  contentId: episode.contentId,
  name: LocaleKeys.series_episode_title.tr(
    namedArgs: {
      'series': SeriesSeasonDetail.seriesTitle(season.name),
      'season': '$seasonNumber',
      'episode': '${episode.number}',
    },
  ),
  poster: season.poster,
  backdrop: season.backdrop,
  backdrops: season.backdrops,
  programType: season.programType,
);
