import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/features/movies/widgets/movie_detail_parts.dart';
import 'package:moai3/features/movies/widgets/movie_detail_shell.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/focus/opening_focus_guard.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/services/movie_synopsis_service.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/services/series_recommendations_api.dart';
import 'package:moai3/services/series_watchlist_service.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/state/series_recommendations_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:provider/provider.dart';

/// Detalle de una serie: la ficha como la de una película, la lista de
/// temporadas (si hay más de una) y los capítulos de la elegida, como
/// cuadrados con su número. OK en un capítulo lo reproduce.
///
/// En el portal cada temporada es un ítem propio ([series] es la que se
/// abrió); el detalle de cada una se pide al elegirla.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({
    super.key,
    required this.series,
    this.fetchSeason,
    this.resolveSynopsis,
    this.resolveEpisode,
    this.initialEpisodeId,
    this.initialEpisodeNumber,
  });

  final MovieItem series;

  /// El capítulo elegido al abrir ("Seguir series" del Inicio): por su
  /// `contentId` o, si no está, por su número. Sin ellos, el primero.
  final String? initialEpisodeId;
  final int? initialEpisodeNumber;

  /// Pide el detalle de una temporada; por defecto
  /// [MoiamovApiService.fetchSeriesSeason]. Los tests lo reemplazan.
  final Future<SeriesSeasonDetail?> Function(String contentId)? fetchSeason;

  /// La sinopsis en español de TMDb (por el id de IMDb de la serie) cuando
  /// la del catálogo falta o está en inglés; por defecto
  /// [MovieSynopsisService.byImdbId]. Los tests lo reemplazan.
  final Future<String?> Function(String imdbId, {bool allowEnglish})?
  resolveSynopsis;

  /// Pide el video de un capítulo; por defecto
  /// [MoiamovApiService.resolveEpisodeStream]. Los tests lo reemplazan.
  final EpisodeStreamResolver? resolveEpisode;

  @override
  State<SeriesDetailScreen> createState() => SeriesDetailScreenState();
}

class SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final FocusNode _backFocus = FocusNode(debugLabel: 'series_detail_back');
  final FocusNode _seasonsFocus = FocusNode(
    debugLabel: 'series_detail_seasons',
  );
  final FocusNode _voteUpFocus = FocusNode(debugLabel: 'series_detail_vote_up');
  final FocusNode _voteDownFocus = FocusNode(
    debugLabel: 'series_detail_vote_down',
  );
  final FocusNode _watchlistFocus = FocusNode(
    debugLabel: 'series_detail_watchlist',
  );
  final FocusNode _episodesFocus = FocusNode(
    debugLabel: 'series_detail_episodes',
  );

  /// Los capítulos van en una fila, como las del Inicio: [episodeHeight] de
  /// alto y por lo menos [episodeMinWidth] de ancho; entran los que caben y
  /// se estiran hasta llenarla, así queda pareja entre las flechas.
  static const double episodeHeight = 52;
  static const double episodeMinWidth = 64;
  static const double episodeGap = 10;

  /// Alto de las píldoras de las temporadas (su fila usa la misma medida que
  /// la de los capítulos).
  static const double seasonHeight = 36;

  /// La foto horizontal a la derecha de la ficha. Escondida por ahora, para
  /// ver cómo queda sin ella.
  static const bool showPreview = false;

  /// Cuánto espera, al pasar de temporada, antes de pedirla: así recorrer
  /// la lista no pide todas.
  static const Duration seasonLoadDelay = Duration(milliseconds: 300);

  /// Detalle de cada temporada ya pedida, por `contentId`.
  final Map<String, SeriesSeasonDetail> _details = {};
  final Set<String> _failed = {};
  final Set<String> _loading = {};

  /// Las temporadas como las lista el portal (llegan con el primer detalle);
  /// puede repetir un número con dos versiones.
  List<SeriesSeason> _allSeasons = const [];

  /// Las que se muestran: una por número, la versión más completa
  /// ([SeriesSeasonDetail.bestSeasons]).
  /// Si el portal no lista temporadas (serie de una sola), la abierta.
  List<SeriesSeason> get _seasons {
    if (_allSeasons.isEmpty) {
      final detail = _detail;
      if (detail == null) return const [];
      return [
        SeriesSeason(
          contentId: _seasonId,
          number: SeriesSeasonDetail.seasonNumber(detail.info) ?? 1,
        ),
      ];
    }
    return SeriesSeasonDetail.bestSeasons(_allSeasons, _details);
  }

  /// La temporada que se ve (su `contentId`).
  late String _seasonId = widget.series.contentId;
  int _episode = 0;

  /// Lo visto de cada temporada (los checks), por `contentId`.
  final Map<String, SeriesSeasonWatch> _watch = {};

  Timer? _seasonTimer;

  @visibleForTesting
  String get debugSeasonId => _seasonId;

  @visibleForTesting
  int get debugEpisodeIndex => _episode;

  SeriesSeasonDetail? get _detail => _details[_seasonId];

  /// La ficha: la de la temporada elegida; mientras carga, la última que
  /// se vio (o la del catálogo), así no salta.
  late MovieItem _info = widget.series;

  /// La sinopsis de TMDb de la serie; se usa en las temporadas cuya
  /// sinopsis del catálogo no sirve. Se pide una sola vez.
  String? _tmdbSynopsis;
  bool _synopsisRequested = false;

  /// Si la sinopsis de la temporada que se ve falta o está en inglés y ya
  /// se sabe el id de IMDb de la serie (llega con el detalle), la pide.
  void _maybeLoadSynopsis() {
    if (_synopsisRequested) return;
    final description = _info.description;
    if (!MovieSynopsisService.needsLookup(description)) return;
    final imdbId = _details.values.map((d) => d.imdbId).nonNulls.firstOrNull;
    if (imdbId == null) return;
    _synopsisRequested = true;
    final resolver =
        widget.resolveSynopsis ?? MovieSynopsisService.instance.byImdbId;
    unawaited(
      resolver(
        imdbId,
        allowEnglish: MovieSynopsisService.isMissing(description),
      ).then<void>(
        (synopsis) {
          if (mounted && synopsis != null && synopsis.isNotEmpty) {
            setState(() => _tmdbSynopsis = synopsis);
          }
        },
        onError: (Object e) {
          debugPrint('⚠️ [Sinopsis] serie $imdbId: $e');
        },
      ),
    );
  }

  /// La sinopsis a mostrar de [info]: la suya o, si no sirve, la de TMDb.
  String? _synopsisOf(MovieItem info) =>
      MovieSynopsisService.needsLookup(info.description)
      ? (_tmdbSynopsis ?? info.description)
      : info.description;

  int get _seasonIndex => _seasons.indexWhere((s) => s.contentId == _seasonId);

  /// La píldora "N temporadas" de la ficha: sólo con más de una.
  bool get _hasSeasonList => _seasons.length > 1;

  /// La fila de temporadas: aun con una sola, para poder marcarla entera
  /// como vista (OK mantenido).
  bool get _hasSeasonRow => _seasons.isNotEmpty;

  List<SeriesEpisode> get _episodes => _detail?.episodes ?? const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load(_seasonId));
    _openingFocus.start();
    SeriesWatchlistService.instance.addListener(_onWatchlistChanged);
    unawaited(SeriesWatchlistService.instance.ensureLoaded());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          context.read<SeriesRecommendationsProvider?>()?.ensureLoaded(),
        );
      }
    });
    for (final node in [_seasonsFocus, _episodesFocus]) {
      node.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _seasonTimer?.cancel();
    _okTimer?.cancel();
    _openingFocus.stop();
    SeriesWatchlistService.instance.removeListener(_onWatchlistChanged);
    _watchlistFocus.dispose();
    _voteUpFocus.dispose();
    _voteDownFocus.dispose();
    _backFocus.dispose();
    _seasonsFocus.dispose();
    _episodesFocus.dispose();
    super.dispose();
  }

  /// Al abrir, el foco en los capítulos hasta la primera tecla
  /// ([OpeningFocusGuard]: en el TV se iba a Atrás).
  late final OpeningFocusGuard _openingFocus = OpeningFocusGuard(
    target: _episodesFocus,
    isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true),
  );

  void _onFocusChange() {
    // Un OK a medio mantener no sigue en otra fila.
    _cancelOk();
    if (mounted) setState(() {});
  }

  Future<void> _load(String contentId) async {
    if (_details.containsKey(contentId) || !_loading.add(contentId)) return;
    _failed.remove(contentId);
    if (mounted) setState(() {});
    final fetch =
        widget.fetchSeason ?? MoiamovApiService.instance.fetchSeriesSeason;
    SeriesSeasonDetail? detail;
    try {
      detail = await fetch(contentId);
    } catch (_) {
      detail = null;
    }
    if (!mounted) return;
    setState(() {
      _loading.remove(contentId);
      if (detail == null) {
        _failed.add(contentId);
        return;
      }
      _details[contentId] = detail;
      if (_allSeasons.isEmpty || detail.seasons.length > _allSeasons.length) {
        _allSeasons = detail.seasons;
      }
      unawaited(
        SeriesWatchService.rememberEpisodeCount(
          contentId,
          detail.episodes.length,
        ).then((_) => _loadWatch()),
      );
      if (contentId == _seasonId) {
        _info = detail.info;
        // A veces la que se abrió no está en la lista con su `contentId`:
        // se la reconoce por el número del nombre ("T13", "S13"), así queda
        // marcada y no se vuelve a pedir.
        if (!_allSeasons.any((s) => s.contentId == _seasonId)) {
          final number = SeriesSeasonDetail.seasonNumber(detail.info);
          final same = _seasons.where((s) => s.number == number).firstOrNull;
          if (same != null) {
            _details[same.contentId] = detail;
            _seasonId = same.contentId;
          }
        }
      }
      _followBestSeason();
      _applyInitialEpisode();
    });
    _maybeLoadSynopsis();
    // Las temporadas repetidas: se piden todas sus versiones para quedarse
    // con la más completa.
    for (final id in SeriesSeasonDetail.duplicated(_allSeasons)) {
      if (!_details.containsKey(id)) unawaited(_load(id));
    }
  }

  /// Ya se eligió el capítulo de [SeriesDetailScreen.initialEpisodeId].
  bool _initialApplied = false;

  /// Al llegar los capítulos de la temporada abierta, elige el pedido (por
  /// `contentId` o número); una sola vez, después manda la persona.
  void _applyInitialEpisode() {
    if (_initialApplied) return;
    final episodes = _detail?.episodes;
    if (episodes == null) return;
    _initialApplied = true;
    final id = widget.initialEpisodeId;
    final number = widget.initialEpisodeNumber;
    var index = id == null || id.isEmpty
        ? -1
        : episodes.indexWhere((e) => e.contentId == id);
    if (index < 0 && number != null) {
      index = episodes.indexWhere((e) => e.number == number);
    }
    if (index >= 0) _episode = index;
  }

  /// Si la temporada que se ve quedó como la versión descartada de una
  /// repetida, pasa a la elegida (con sus capítulos desde el primero).
  void _followBestSeason() {
    if (_seasonIndex >= 0) return;
    final number = _allSeasons
        .where((s) => s.contentId == _seasonId)
        .firstOrNull
        ?.number;
    if (number == null) return;
    final best = _seasons.where((s) => s.number == number).firstOrNull;
    final detail = best == null ? null : _details[best.contentId];
    if (best == null || detail == null) return;
    _seasonId = best.contentId;
    _info = detail.info;
    // La misma temporada en otra versión: el mismo capítulo (si está).
    _episode = detail.episodes.isEmpty
        ? 0
        : _episode.clamp(0, detail.episodes.length - 1);
  }

  /// Lee lo visto de todas las temporadas conocidas.
  Future<void> _loadWatch() async {
    final ids = {for (final s in _seasons) s.contentId, _seasonId};
    final loaded = {
      for (final id in ids) id: await SeriesWatchService.season(id),
    };
    if (mounted) setState(() => _watch.addAll(loaded));
  }

  bool _episodeWatched(SeriesEpisode episode) =>
      _watch[_seasonId]?.watched.contains(episode.contentId) ?? false;

  /// Pasa a otra temporada: la ficha y los capítulos son de ésa (se pide
  /// después de [seasonLoadDelay] si no está).
  void _selectSeason(int index) {
    final season = _seasons[index];
    setState(() {
      _seasonId = season.contentId;
      _episode = 0;
      if (_details[season.contentId] case final detail?) _info = detail.info;
    });
    _maybeLoadSynopsis();
    _seasonTimer?.cancel();
    if (!_details.containsKey(season.contentId)) {
      _seasonTimer = Timer(seasonLoadDelay, () => _load(season.contentId));
    }
  }

  void _selectEpisode(int index) => setState(() => _episode = index);

  void _focusEpisodes() => _episodesFocus.requestFocus();

  void _focusTop() {
    if (_hasSeasonRow) {
      _seasonsFocus.requestFocus();
    } else {
      _watchlistFocus.requestFocus();
    }
  }

  /// OK en una fila: corto, al soltar ([onPress]); mantenido
  /// [TvTiming.longPress], [onLongPress] (y el corto no).
  Timer? _okTimer;
  bool _okDown = false;
  bool _okLong = false;

  KeyEventResult _onOk(
    KeyEvent event, {
    required VoidCallback onPress,
    required VoidCallback onLongPress,
  }) {
    if (event is KeyDownEvent) {
      _okDown = true;
      _okLong = false;
      _okTimer?.cancel();
      _okTimer = Timer(TvTiming.longPress, () {
        _okLong = true;
        onLongPress();
      });
    } else if (event is KeyUpEvent && _okDown) {
      // Sin [_okDown]: es el OK que abrió el detalle, se ignora.
      _okTimer?.cancel();
      _okDown = false;
      if (!_okLong) onPress();
    }
    return KeyEventResult.handled;
  }

  void _cancelOk() {
    _okTimer?.cancel();
    _okDown = false;
  }

  KeyEventResult _onSeasonsKey(FocusNode node, KeyEvent event) {
    if (TvKeyHandler.isActionKey(event.logicalKey)) {
      return _onOk(
        event,
        onPress: _focusEpisodes,
        onLongPress: () => unawaited(_toggleSeasonWatched()),
      );
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final index = _seasonIndex;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (index > 0) {
        _selectSeason(index - 1);
      } else {
        _backFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (index < _seasons.length - 1) _selectSeason(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusEpisodes();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      // Arriba, a la derecha: Marcar.
      _watchlistFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onEpisodesKey(FocusNode node, KeyEvent event) {
    if (TvKeyHandler.isActionKey(event.logicalKey)) {
      // Si los capítulos no cargaron, OK vuelve a pedirlos.
      if (_failed.contains(_seasonId)) {
        if (event is KeyDownEvent) unawaited(_load(_seasonId));
        return KeyEventResult.handled;
      }
      return _onOk(
        event,
        onPress: () => unawaited(_playEpisode()),
        onLongPress: () => unawaited(_toggleEpisodeWatched()),
      );
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = _episodes.length;
    final index = _episode;
    // ←/→ recorren la fila (mantenidas, también); sólo un toque sale de ella.
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _selectEpisode(index - 1);
      } else if (event is KeyDownEvent) {
        _backFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < count - 1) _selectEpisode(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent) _focusTop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  /// OK mantenido en un capítulo: lo marca como visto, o le saca la marca.
  Future<void> _toggleEpisodeWatched() async {
    final episodes = _episodes;
    if (_episode >= episodes.length) return;
    final episode = episodes[_episode];
    final watched = !_episodeWatched(episode);
    await SeriesWatchService.setWatched(
      seasonId: _seasonId,
      episodeIds: [episode.contentId],
      watched: watched,
      episodeCount: episodes.length,
    );
    if (watched) {
      // El más avanzado de los vistos: marcar el 2 después del 5 no vuelve
      // la tarjeta atrás.
      final seen = (await SeriesWatchService.season(_seasonId)).watched;
      final last = episodes.lastIndexWhere((e) => seen.contains(e.contentId));
      await _rememberInContinue(_seasonId, last < 0 ? _episode : last);
    }
    await _loadWatch();
  }

  /// Marcado a mano como visto: la serie entra (o sigue) en "Seguir
  /// series" del Inicio, con el capítulo [episodeIndex] de [seasonId] como
  /// el último visto (la tarjeta muestra el siguiente).
  Future<void> _rememberInContinue(String seasonId, int episodeIndex) async {
    final playlist = SeriesPlaylist(
      seasons: _seasons,
      details: _details,
      startSeasonId: seasonId,
      startEpisodeIndex: episodeIndex,
    );
    await SeriesContinueService.record(playlist.continueEntry(Duration.zero));
  }

  /// OK mantenido en una temporada: marca todos sus capítulos como vistos;
  /// si ya estaban todos, les saca la marca.
  Future<void> _toggleSeasonWatched() async {
    final seasonId = _seasonId;
    if (!_details.containsKey(seasonId)) {
      _seasonTimer?.cancel();
      await _load(seasonId);
    }
    final episodes = _details[seasonId]?.episodes;
    if (episodes == null || episodes.isEmpty) return;
    final watched = !(_watch[seasonId]?.complete ?? false);
    await SeriesWatchService.setWatched(
      seasonId: seasonId,
      episodeIds: [for (final e in episodes) e.contentId],
      watched: watched,
      episodeCount: episodes.length,
    );
    // Vista entera: en "Seguir series", lo que sigue es la próxima.
    if (watched) await _rememberInContinue(seasonId, episodes.length - 1);
    await _loadWatch();
  }

  bool _starting = false;

  /// El capítulo que se está pidiendo: su número se cambia por una ruedita
  /// hasta que abre el reproductor.
  int? _loadingEpisode;

  /// OK en un capítulo: lo reproduce (si quedó a la mitad, pregunta si
  /// retomar) y sigue con los siguientes. Al volver, queda elegido el último
  /// que se vio.
  Future<void> _playEpisode() async {
    final detail = _detail;
    if (_starting || detail == null || _episode >= detail.episodes.length) {
      return;
    }
    _starting = true;
    try {
      int? startAt;
      final resume = await SeriesWatchService.resumeAt(
        detail.episodes[_episode].contentId,
      );
      if (!mounted) return;
      if (resume != null) {
        final answer = await askResume(context, resume.inSeconds);
        if (answer == null || !mounted) return;
        if (answer) startAt = resume.inSeconds;
      }
      setState(() => _loadingEpisode = _episode);
      final playlist = SeriesPlaylist(
        seasons: _seasons,
        details: _details,
        startSeasonId: _seasonId,
        startEpisodeIndex: _episode,
        fetchSeason: widget.fetchSeason,
        resolveStream: widget.resolveEpisode,
        recommendationKey: _recommendationKey,
        onStarted: () {
          if (mounted) setState(() => _loadingEpisode = null);
        },
      );
      await playEpisode(context, playlist, startAt: startAt);
      if (!mounted) return;
      setState(() {
        _loadingEpisode = null;
        _details.addAll(playlist.details);
        if (playlist.seasonId != _seasonId) {
          _seasonId = playlist.seasonId;
          _info = _details[_seasonId]!.info;
        }
        _episode = playlist.episodeIndex;
      });
      await _loadWatch();
    } finally {
      _starting = false;
      if (mounted && _loadingEpisode != null) {
        setState(() => _loadingEpisode = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MovieDetailShell(
      backFocusNode: _backFocus,
      onBackForward: _focusEpisodes,
      tabTitle: LocaleKeys.series_detail_tab.tr(),
      svgIcon: MoaiIcons.seriesSvg,
      ambientUrl: _info.ambientBackdrop,
      content: _content(context, scheme),
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme) {
    final info = _info;
    final image = info.stageImages.isNotEmpty
        ? info.stageImages.first
        : info.effectiveBackdrop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 6, child: _infoColumn(context, scheme)),
              const SizedBox(width: 24),
              // Sin la vista previa, su lugar queda libre (se ve la
              // foto difuminada de arriba).
              if (showPreview)
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _image(scheme, image),
                    ),
                  ),
                )
              else
                // Sin la vista previa: abajo a la derecha, Marcar (como en
                // películas, para verla después).
                Expanded(
                  flex: 5,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: _watchlistButton(),
                  ),
                ),
            ],
          ),
        ),
        if (_hasSeasonRow) ...[
          const SizedBox(height: 14),
          _rowLabel(LocaleKeys.series_seasons_label.tr()),
          _seasonList(),
        ],
        const SizedBox(height: 12),
        _rowLabel(LocaleKeys.series_episodes_label.tr()),
        _episodeGrid(context, scheme),
      ],
    );
  }

  /// Todas las temporadas conocidas de la serie (también las versiones
  /// repetidas): la marca se reconoce por cualquiera.
  Set<String> get _allSeasonIds => {
    for (final s in _allSeasons) s.contentId,
    _seasonId,
    widget.series.contentId,
  };

  /// La serie está en "Series marcadas".
  bool get _marked => SeriesWatchlistService.instance.contains(_allSeasonIds);

  void _onWatchlistChanged() {
    if (mounted) setState(() {});
  }

  /// Marcar / Desmarcar y, con amigos, 👍 / 👎 (como en películas): la
  /// serie (no la temporada) va a "Series marcadas" del Inicio, que la abre
  /// en la primera temporada; el 👍 se comparte con los amigos.
  Widget _watchlistButton() {
    final marked = _marked;
    final recommendations = context.watch<SeriesRecommendationsProvider?>();
    final canRecommend = recommendations?.canRecommend ?? false;
    final vote = recommendations?.voteOf(_recommendationKey);
    Widget voteButton(MovieVote value) {
      final up = value == MovieVote.up;
      return TvFocusButton(
        focusNode: up ? _voteUpFocus : _voteDownFocus,
        label: '',
        icon: up ? MoaiIcons.vodRecommend : MoaiIcons.vodNotRecommend,
        variant: vote == value
            ? TvButtonVariant.secondary
            : TvButtonVariant.surface,
        height: 38,
        fontSize: 13,
        radius: 20,
        onPressed: () => unawaited(_toggleVote(value)),
        onArrowLeft: up
            ? _watchlistFocus.requestFocus
            : _voteUpFocus.requestFocus,
        onArrowRight: up ? _voteDownFocus.requestFocus : null,
        onArrowUp: _backFocus.requestFocus,
        onArrowDown: _focusTop,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TvFocusButton(
          focusNode: _watchlistFocus,
          label: marked
              ? LocaleKeys.movies_watchlist_added.tr()
              : LocaleKeys.movies_watchlist_add.tr(),
          icon: marked ? MoaiIcons.vodWatchlistRemove : MoaiIcons.vodWatchlist,
          variant: marked ? TvButtonVariant.tonal : TvButtonVariant.surface,
          height: 38,
          fontSize: 13,
          radius: 20,
          onPressed: () => unawaited(_toggleWatchlist()),
          onArrowLeft: _backFocus.requestFocus,
          onArrowRight: canRecommend ? _voteUpFocus.requestFocus : null,
          onArrowUp: _backFocus.requestFocus,
          onArrowDown: _focusTop,
        ),
        if (canRecommend) ...[
          const SizedBox(width: 10),
          voteButton(MovieVote.up),
          const SizedBox(width: 10),
          voteButton(MovieVote.down),
        ],
      ],
    );
  }

  /// La serie para recomendar: la misma en todos los TV
  /// ([SeriesSeasonDetail.recommendationKey]).
  String get _recommendationKey =>
      SeriesSeasonDetail.recommendationKey(_allSeasons, _seasonId);

  /// La serie como película, para recomendarla (se abre en la primera
  /// temporada).
  MovieItem get _recommendationItem {
    final key = _recommendationKey;
    final info = _details[key]?.info ?? _info;
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

  /// Hasta qué temporada se vio: la de número más alto con algún capítulo
  /// visto; si ninguna, la que se está mirando.
  int get _seasonReached {
    var reached = 0;
    for (final season in _seasons) {
      final seen = _watch[season.contentId]?.watched.isNotEmpty ?? false;
      if (seen && season.number > reached) reached = season.number;
    }
    if (reached > 0) return reached;
    return _seasonIndex >= 0 ? _seasons[_seasonIndex].number : 1;
  }

  Future<void> _toggleVote(MovieVote vote) async {
    final recommendations = context.read<SeriesRecommendationsProvider?>();
    await recommendations?.toggleVote(
      _recommendationItem,
      vote,
      extra: {SeriesRecommendationsApi.seasonKey: _seasonReached},
    );
  }

  Future<void> _toggleWatchlist() async {
    final first = _seasons.firstOrNull;
    final info = _details[first?.contentId]?.info ?? _info;
    await SeriesWatchlistService.instance.toggle(
      MovieItem(
        contentId: first?.contentId ?? _seasonId,
        name: SeriesSeasonDetail.seriesTitle(info.name),
        poster: info.poster,
        backdrop: info.backdrop,
        backdrops: info.backdrops,
        year: info.year,
        score: info.score,
        programType: 'teleplay',
      ),
      _allSeasonIds,
    );
  }

  /// La foto horizontal de la temporada, redondeada como la Hero.
  Widget _image(ColorScheme scheme, String? url) {
    final empty = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: MoaiSvgIcon(
          MoaiIcons.seriesSvg,
          size: MoaiIconSizes.xxl,
          color: scheme.outline,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: url == null || url.isEmpty
          ? empty
          : CachedNetworkImage(
              imageUrl: url,
              cacheManager: MovieImageCache.photos,
              fit: BoxFit.cover,
              memCacheWidth: 720,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => empty,
              errorWidget: (_, _, _) => empty,
            ),
    );
  }

  Widget _infoColumn(BuildContext context, ColorScheme scheme) {
    final info = _info;
    final title = SeriesSeasonDetail.seriesTitle(info.name);
    final alias = SeriesSeasonDetail.seriesTitle((info.alias ?? '').trim());
    final hasAlias =
        alias.isNotEmpty && alias.toLowerCase() != title.toLowerCase();
    final year = info.formattedYear;
    final genres = info.genreList;
    final scorePill = movieScorePill(context, info);
    final episodes = _detail?.episodes.length;
    final director = info.formattedDirector ?? '';

    TvMetaPill pill(IconData icon, String label) => TvMetaPill(
      dense: true,
      color: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
      icon: icon,
      label: label,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailTitle(title),
        const SizedBox(height: 6),
        if (hasAlias) ...[MovieDetailAlias(alias), const SizedBox(height: 8)],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ?scorePill,
            if (year != null && year.isNotEmpty)
              pill(MoaiIcons.vodReleaseDate, year),
            if (_hasSeasonList)
              TvMetaPill(
                dense: true,
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                svgIcon: MoaiIcons.seriesSeasonsSvg,
                label: LocaleKeys.series_seasons_count.tr(
                  namedArgs: {'count': '${_seasons.length}'},
                ),
              ),
            if (episodes != null && episodes > 0)
              pill(
                MoaiIcons.vodDuration,
                episodes == 1
                    ? LocaleKeys.series_episodes_one.tr()
                    : LocaleKeys.series_episodes_count.tr(
                        namedArgs: {'count': '$episodes'},
                      ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (genres.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in genres) TvMovieGenreChip(label: g)],
          ),
          const SizedBox(height: 12),
        ],
        if (director.isNotEmpty) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_director.tr(),
            value: director,
          ),
          const SizedBox(height: 4),
        ],
        if (info.formattedCast case final cast?) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_cast.tr(),
            value: cast,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
        ],
        Expanded(child: MovieSynopsisBlock(description: _synopsisOf(info))),
      ],
    );
  }

  /// Separación entre una fila y sus puntos, y tamaño de cada punto (los de
  /// [TvWindowedRow]).
  static const double _dotsGap = 8;
  static const double _dotSize = 5;

  /// Más páginas que éstas no entran (One Piece tiene más de cien): se ven
  /// las de alrededor de la actual, y los puntos de las puntas, chicos,
  /// avisan que hay más (como [MoviePositionDots]).
  static const int _maxDots = 24;

  /// El rótulo de una fila ("Temporadas", "Capítulos"), en el gris de
  /// "Director:".
  Widget _rowLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: movieDetailLabelStyle(context)),
  );

  /// Cuántos recuadros entran en [width] y de qué ancho (ver [_edgeRow]).
  static (int, double) _fitIn(double width) {
    final fit = ((width + episodeGap) ~/ (episodeMinWidth + episodeGap)).clamp(
      1,
      1 << 20,
    );
    return (fit, (width - (fit - 1) * episodeGap) / fit);
  }

  /// Mientras llega la temporada: una línea de carga indeterminada, la de
  /// la pantalla de carga (acento sobre un riel tenue), en el medio del alto
  /// de la fila: no salta al llegar.
  Widget _loadingRow(ColorScheme scheme) => SizedBox(
    key: const ValueKey('episodes_loading'),
    height: episodeHeight,
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          minHeight: 4,
          color: scheme.primary,
          backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
    ),
  );

  /// Una fila como las del Inicio ([HomeRowWindow]): se corre para que el
  /// elegido siempre se vea. Entran los que caben a [episodeMinWidth] y se
  /// estiran hasta llenar el ancho: como temporadas y capítulos usan la
  /// misma medida, T1 queda arriba del capítulo 1. Con menos, del mismo
  /// tamaño y desde la izquierda. Si no entran todos, abajo un punto por
  /// página, como en las listas ([TvWindowedRow], acá centrados).
  Widget _edgeRow({
    required Key key,
    required String dotsId,
    required double height,
    required int count,
    required int selected,
    required Widget Function(int index, double width) item,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (fit, tileWidth) = _fitIn(constraints.maxWidth);
        final visible = fit.clamp(1, count);
        final row = SizedBox(
          height: height,
          child: HomeRowWindow(
            key: key,
            count: count,
            visible: visible,
            selected: selected,
            builder: (start) => Row(
              children: [
                for (var i = start; i < start + visible; i++) ...[
                  if (i > start) const SizedBox(width: episodeGap),
                  item(i, tileWidth),
                ],
              ],
            ),
          ),
        );
        final pages = (count + fit - 1) ~/ fit;
        if (pages <= 1) return row;
        final scheme = Theme.of(context).colorScheme;
        final active = (selected ~/ fit).clamp(0, pages - 1);
        final shown = pages.clamp(1, _maxDots);
        final from = (active - shown ~/ 2).clamp(0, pages - shown);
        final to = from + shown;
        bool more(int page) =>
            (page == from && from > 0) || (page == to - 1 && to < pages);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            const SizedBox(height: _dotsGap),
            Row(
              key: ValueKey('${dotsId}_dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var page = from; page < to; page++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    // El de la página actual se estira: se lee de lejos.
                    width: page == active
                        ? _dotSize * 2.4
                        : more(page)
                        ? _dotSize * 0.6
                        : _dotSize,
                    height: more(page) ? _dotSize * 0.6 : _dotSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_dotSize),
                      color: page == active
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Las temporadas ("1", "2"…; el rótulo "Temporadas" ya dice qué son), de
  /// cristal como los capítulos: la que se
  /// ve, con el borde del foco si la fila lo tiene y sólida en el acento si
  /// no ([_SeasonPill]). ←/→ pasan de una a otra.
  Widget _seasonList() {
    final focused = _seasonsFocus.hasFocus;
    final current = _seasonIndex;
    return Focus(
      focusNode: _seasonsFocus,
      onKeyEvent: _onSeasonsKey,
      child: _edgeRow(
        key: const ValueKey('seasons'),
        dotsId: 'seasons',
        height: seasonHeight,
        count: _seasons.length,
        selected: current,
        item: (i, width) => _SeasonPill(
          key: ValueKey('season-${_seasons[i].number}'),
          width: width,
          label: '${_seasons[i].number}',
          current: i == current,
          focused: focused && i == current,
          watched: _watch[_seasons[i].contentId]?.complete ?? false,
          onTap: () {
            _seasonsFocus.requestFocus();
            _selectSeason(i);
          },
        ),
      ),
    );
  }

  /// Los capítulos de la temporada en una fila ([_edgeRow]).
  Widget _episodeGrid(BuildContext context, ColorScheme scheme) {
    final Widget content;
    if (_loading.contains(_seasonId) ||
        (_detail == null && !_failed.contains(_seasonId))) {
      content = _loadingRow(scheme);
    } else if (_episodes.isEmpty) {
      content = SizedBox(
        height: episodeHeight,
        child: Center(
          child: Text(
            _failed.contains(_seasonId)
                ? LocaleKeys.series_episodes_error.tr()
                : LocaleKeys.series_episodes_empty.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      final episodes = _episodes;
      final focused = _episodesFocus.hasFocus;
      content = _edgeRow(
        // Otra temporada empieza desde su primer capítulo.
        key: ValueKey(_seasonId),
        dotsId: 'episodes',
        height: episodeHeight,
        count: episodes.length,
        selected: _episode,
        item: (i, width) => _EpisodeTile(
          key: ValueKey('episode-${episodes[i].number}'),
          width: width,
          number: episodes[i].number,
          selected: focused && i == _episode,
          current: i == _episode,
          watched: _episodeWatched(episodes[i]),
          loading: i == _loadingEpisode,
          onTap: () {
            _episodesFocus.requestFocus();
            _selectEpisode(i);
          },
        ),
      );
    }
    return Focus(
      focusNode: _episodesFocus,
      onKeyEvent: _onEpisodesKey,
      child: content,
    );
  }
}

/// El número de lo visto: más grande, más grueso y en el verde del modo
/// ([MoaiPalette.watched]). Sobre el acento sólido, en [onPrimary] (el
/// verde no se lee ahí), igual de grande y grueso.
TextStyle _numberStyle(
  BuildContext context, {
  required double size,
  required bool current,
  required bool watched,
  Color? onSolid,
}) {
  final scheme = Theme.of(context).colorScheme;
  return MoaiText.display(
    context,
    fontSize: watched ? size + 4 : size,
    fontWeight: watched
        ? FontWeight.w900
        : current
        ? FontWeight.w700
        : FontWeight.w600,
    color:
        onSolid ??
        (watched ? MoaiPalette.of(context).watched : scheme.onSurface),
  );
}

/// Una temporada, del mismo cristal que los capítulos ([_EpisodeTile]): con
/// el foco en la fila, la que se ve lleva sólo el borde del foco; sin él,
/// queda sólida en el acento para que se sepa cuál es. Completa (todos sus
/// capítulos vistos), en forma de píldora y con el número más grande, más
/// grueso y verde.
class _SeasonPill extends StatelessWidget {
  const _SeasonPill({
    super.key,
    required this.width,
    required this.label,
    required this.current,
    required this.focused,
    required this.watched,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool current;
  final bool focused;

  /// Todos sus capítulos vistos.
  final bool watched;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = current && !focused;
    // Vista: forma de píldora (bordes redondos del todo).
    final radius = watched ? SeriesDetailScreenState.seasonHeight / 2 : 10.0;
    final text = Text(
      label,
      maxLines: 1,
      style: _numberStyle(
        context,
        size: 15,
        current: current,
        watched: watched,
        onSolid: solid ? scheme.onPrimary : null,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: KeyedSubtree(
        key: ValueKey(watched ? 'watched' : 'unwatched'),
        child: solid
            ? Container(
                width: width,
                height: SeriesDetailScreenState.seasonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: text,
              )
            : MoaiGlass(
                width: width,
                height: SeriesDetailScreenState.seasonHeight,
                borderRadius: radius,
                elevated: false,
                solid: true,
                focused: focused,
                alignment: Alignment.center,
                child: text,
              ),
      ),
    );
  }
}

/// Un capítulo: recuadro de cristal con su número; elegido, con el borde
/// del foco; visto, en forma de píldora y con el número más grande, más
/// grueso y verde.
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.width,
    required this.number,
    required this.selected,
    required this.current,
    required this.watched,
    required this.onTap,
    this.loading = false,
  });

  final double width;
  final int number;
  final bool selected;

  /// El elegido aunque el foco esté en otro lado: el número más marcado.
  final bool current;

  /// Visto.
  final bool watched;

  /// Se está pidiendo su video: una ruedita en vez del número.
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: KeyedSubtree(
        key: ValueKey(watched ? 'watched' : 'unwatched'),
        child: MoaiGlass(
          width: width,
          height: SeriesDetailScreenState.episodeHeight,
          borderRadius: watched
              ? SeriesDetailScreenState.episodeHeight / 2
              : 10,
          elevated: false,
          solid: true,
          focused: selected,
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  key: const ValueKey('episode_loading'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : Text(
                  '$number',
                  style: _numberStyle(
                    context,
                    size: 17,
                    current: current,
                    watched: watched,
                  ),
                ),
        ),
      ),
    );
  }
}
