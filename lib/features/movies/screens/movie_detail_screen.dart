import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/movies/widgets/movie_detail_parts.dart';
import 'package:moai3/focus/opening_focus_guard.dart';
import 'package:moai3/features/movies/widgets/movie_detail_shell.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/features/movies/widgets/tv_movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_metadata_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/titan_ranger_service.dart';
import 'package:moai3/services/youtube_launcher.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Pantalla de detalle de película para Smart TV con diseño Split Cinemático 60/40.
class MovieDetailScreen extends StatefulWidget {
  final MovieItem movie;

  /// Resuelve el stream al reproducir; por defecto [MoiamovApiService]. Los
  /// tests lo reemplazan para no salir a la red.
  final Future<ResolvedPlayStream?> Function(MovieItem movie)? resolveStream;

  /// Resuelve el año de estreno real; por defecto [MovieMetadataService.instance.resolveYear].
  /// Los tests lo reemplazan si quieren simular red o respuesta fija.
  final Future<String?> Function(MovieItem movie)? resolveYear;

  /// Abre un adelanto en YouTube; por defecto [YoutubeLauncher.open]. `false`
  /// si no se pudo.
  final Future<bool> Function(String videoId)? openTrailer;

  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.resolveStream,
    this.resolveYear,
    this.openTrailer,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'movie_detail_back');
  final FocusNode _watchlistFocusNode = FocusNode(
    debugLabel: 'movie_detail_watchlist',
  );
  final FocusNode _voteUpFocusNode = FocusNode(debugLabel: 'movie_detail_up');
  final FocusNode _voteDownFocusNode = FocusNode(
    debugLabel: 'movie_detail_down',
  );
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'movie_detail_hero');
  bool _inWatchlist = false;
  bool _isLoadingStream = false;
  MovieWatchProgress? _watchProgress;
  String? _resolvedYear;

  /// Un tráiler se ve de una vez: sin progreso ni "Marcar como interesante".
  bool get _isTrailer => widget.movie.isTrailer;

  /// Pestaña lateral: "Película" o "Adelanto".
  String get _tabTitle => _isTrailer
      ? LocaleKeys.movies_trailer_tab.tr()
      : LocaleKeys.movies_detail_tab.tr();

  @override
  void initState() {
    super.initState();
    // Titan tarda 1,5 s en quedar listo la primera vez: arranca mientras se
    // mira el detalle, no al tocar Reproducir. Una vez por arranque. Un
    // adelanto no lo usa (se ve en YouTube).
    if (!_isTrailer) unawaited(TitanRangerService.init());
    _resolvedYear = widget.movie.formattedYear;
    if (_resolvedYear == null) {
      _loadYear();
    }
    if (!_isTrailer) {
      _inWatchlist = MovieWatchlistService.instance.contains(
        widget.movie.contentId,
      );
      _loadProgress();
      _loadWatchlist();
    }
    _openingFocus.start();
  }

  /// Al abrir, el foco en la ficha hasta la primera tecla
  /// ([OpeningFocusGuard]: en el TV se iba a Atrás).
  late final OpeningFocusGuard _openingFocus = OpeningFocusGuard(
    target: _heroFocusNode,
    isActive: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true),
  );

  Future<void> _loadWatchlist() async {
    final watchlist = MovieWatchlistService.instance;
    await watchlist.ensureLoaded();
    if (mounted) {
      final contains = watchlist.contains(widget.movie.contentId);
      if (_inWatchlist != contains) {
        setState(() => _inWatchlist = contains);
      }
    }
  }

  Future<void> _loadProgress() async {
    final progress = await MovieProgressService.getProgress(
      widget.movie.contentId,
    );
    if (mounted && progress != null) {
      setState(() => _watchProgress = progress);
    }
  }

  Future<void> _loadYear() async {
    final resolver =
        widget.resolveYear ?? MovieMetadataService.instance.resolveYear;
    final year = await resolver(widget.movie);
    if (mounted && year != null && year.isNotEmpty) {
      setState(() => _resolvedYear = year);
    }
  }

  @override
  void didUpdateWidget(covariant MovieDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.contentId != widget.movie.contentId) {
      _resolvedYear = widget.movie.formattedYear;
      if (_resolvedYear == null) {
        _loadYear();
      }
    }
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    _watchlistFocusNode.dispose();
    _voteUpFocusNode.dispose();
    _voteDownFocusNode.dispose();
    _openingFocus.stop();
    _heroFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onPlayPressed() async {
    if (_isLoadingStream) return;
    if (_isTrailer) return _openTrailer();

    // Retomar o desde el principio.
    int? startAt;
    final progress = _watchProgress;
    if (progress != null && progress.canResume) {
      final resume = await askResume(context, progress.positionSeconds);
      if (resume == null || !mounted) return;
      startAt = resume ? progress.positionSeconds : null;
    }

    setState(() => _isLoadingStream = true);
    await playMovie(
      context,
      widget.movie,
      startAt: startAt,
      resolveStream: widget.resolveStream,
    );
    if (!mounted) return;
    setState(() => _isLoadingStream = false);

    await _loadProgress();
    // Si quedó vista, salió de Interesantes: el botón lo refleja.
    await _loadWatchlist();
    if (mounted) _heroFocusNode.requestFocus();
  }

  /// Un adelanto se ve en la app de YouTube; Atrás allá vuelve acá.
  Future<void> _openTrailer() async {
    final open = widget.openTrailer ?? YoutubeLauncher.open;
    final opened = await open(widget.movie.youtubeTrailerKey!);
    if (!opened && mounted) {
      MoaiSnackBar.showError(
        context,
        message: LocaleKeys.movies_trailer_open_error.tr(),
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _toggleWatchlist() async {
    // Se pinta al instante; si no se pudo guardar, vuelve atrás.
    final wanted = !_inWatchlist;
    setState(() => _inWatchlist = wanted);
    try {
      final saved = await MovieWatchlistService.instance.toggle(widget.movie);
      if (mounted && saved != wanted) setState(() => _inWatchlist = saved);
    } catch (_) {
      if (mounted) setState(() => _inWatchlist = !wanted);
    }
  }

  void _toggleVote(MovieVote vote) {
    final recommendations = context.read<MovieRecommendationsProvider>();
    final recommending =
        vote == MovieVote.up &&
        recommendations.voteOf(widget.movie.contentId) != MovieVote.up;
    unawaited(recommendations.toggleVote(widget.movie, vote));
    if (!recommending) return;
    MoaiSnackBar.show(
      context,
      message: LocaleKeys.movies_recommend_sent.tr(),
      icon: MoaiIcons.vodRecommend,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final movie = widget.movie;
    final canRecommend =
        !_isTrailer &&
        context.select(
          (MovieRecommendationsProvider? r) => r?.canRecommend ?? false,
        );
    final vote = context.select(
      (MovieRecommendationsProvider? r) => r?.voteOf(movie.contentId),
    );

    return MovieDetailShell(
      backFocusNode: _backFocusNode,
      onBackForward: _heroFocusNode.requestFocus,
      tabTitle: _tabTitle,
      ambientUrl: movie.ambientBackdrop,
      tabBuilder: (index, isExpanded) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              const Spacer(),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  _tabTitle,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                MoaiIcons.vodPoster,
                size: MoaiIconSizes.md,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ],
          ),
        );
      },
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Columna Izquierda: Información de la película y acciones
          Expanded(flex: 6, child: _buildInfoColumn(context, scheme, movie)),
          const SizedBox(width: 24),
          // Columna Derecha: Backdrop 16:9 alineado arriba con Play central
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: TvMovieHeroCard(
                    focusNode: _heroFocusNode,
                    imageUrl: movie.stageImages.isNotEmpty
                        ? movie.stageImages.first
                        : movie.effectiveBackdrop,
                    imageUrls: movie.stageImages,
                    movieTitle: movie.displayName,
                    isLoading: _isLoadingStream,
                    // Siempre "Reproducir": si hay
                    // dónde retomar, se pregunta al
                    // tocarlo.
                    playLabel: LocaleKeys.movies_play.tr(),
                    onPressed: _onPlayPressed,
                    onArrowLeft: _backFocusNode.requestFocus,
                    onArrowDown: _isTrailer
                        ? null
                        : _watchlistFocusNode.requestFocus,
                    onArrowUp: _backFocusNode.requestFocus,
                  ),
                ),
                const SizedBox(height: 12),
                // Un tráiler no va a Interesantes:
                // sin botón, mismo lugar para que
                // la Hero no se mueva.
                if (_isTrailer)
                  const SizedBox(height: 38)
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TvFocusButton(
                          focusNode: _watchlistFocusNode,
                          label: _inWatchlist
                              ? LocaleKeys.movies_watchlist_added.tr()
                              : LocaleKeys.movies_watchlist_add.tr(),
                          icon: _inWatchlist
                              ? MoaiIcons.vodWatchlistRemove
                              : MoaiIcons.vodWatchlist,
                          variant: _inWatchlist
                              ? TvButtonVariant.tonal
                              : TvButtonVariant.surface,
                          height: 38,
                          fontSize: 13,
                          radius: 20,
                          onPressed: _toggleWatchlist,
                          onArrowLeft: _backFocusNode.requestFocus,
                          onArrowRight: canRecommend
                              ? _voteUpFocusNode.requestFocus
                              : null,
                          onArrowUp: _heroFocusNode.requestFocus,
                        ),
                        if (canRecommend) ...[
                          const SizedBox(width: 10),
                          TvFocusButton(
                            focusNode: _voteUpFocusNode,
                            label: '',
                            icon: MoaiIcons.vodRecommend,
                            variant: vote == MovieVote.up
                                ? TvButtonVariant.secondary
                                : TvButtonVariant.surface,
                            height: 38,
                            fontSize: 13,
                            radius: 20,
                            onPressed: () => _toggleVote(MovieVote.up),
                            onArrowLeft: _watchlistFocusNode.requestFocus,
                            onArrowRight: _voteDownFocusNode.requestFocus,
                            onArrowUp: _heroFocusNode.requestFocus,
                          ),
                          const SizedBox(width: 10),
                          TvFocusButton(
                            focusNode: _voteDownFocusNode,
                            label: '',
                            icon: MoaiIcons.vodNotRecommend,
                            variant: vote == MovieVote.down
                                ? TvButtonVariant.secondary
                                : TvButtonVariant.surface,
                            height: 38,
                            fontSize: 13,
                            radius: 20,
                            onPressed: () => _toggleVote(MovieVote.down),
                            onArrowLeft: _voteUpFocusNode.requestFocus,
                            onArrowUp: _heroFocusNode.requestFocus,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    ColorScheme scheme,
    MovieItem movie,
  ) {
    final year = _resolvedYear ?? movie.formattedYear;
    final duration = movie.formattedDuration;
    final genres = movie.genreList;
    final scorePill = movieScorePill(context, movie);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final alias = (movie.alias ?? '').trim();
    final hasAlias =
        alias.isNotEmpty && alias.toLowerCase() != movie.name.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Título, en cristal con el degradado de los encabezados.
        MovieDetailTitle(movie.displayName),
        const SizedBox(height: 6),

        // 2. Título original / Alias
        if (hasAlias) ...[MovieDetailAlias(alias), const SizedBox(height: 8)],

        // 3. Fila de metadatos rápidos (Puntuación, Año, Duración, Progreso).
        // La calidad no va: recién se sabe al resolver el stream.
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ?scorePill,
            if (year != null && year.isNotEmpty)
              TvMetaPill(
                dense: true,
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.vodReleaseDate,
                label: year,
              ),
            // La duración de un tráiler en el catálogo es la de la película.
            if (!movie.isTrailer && duration != null && duration.isNotEmpty)
              TvMetaPill(
                dense: true,
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.vodDuration,
                label: duration,
              ),
            if (_watchProgress != null)
              if (_watchProgress!.isCompleted)
                TvMetaPill(
                  dense: true,
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  foreground: dark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF047857),
                  icon: MoaiIcons.vodWatched,
                  label: LocaleKeys.movies_watched.tr(),
                )
              else if (_watchProgress!.canResume)
                TvMetaPill(
                  dense: true,
                  color: scheme.primary.withValues(alpha: 0.2),
                  foreground: scheme.primary,
                  icon: MoaiIcons.vodResume,
                  label: LocaleKeys.movies_watched_percent.tr(
                    namedArgs: {
                      'percent':
                          '${(_watchProgress!.progressPercentage * 100).toInt()}',
                    },
                  ),
                ),
          ],
        ),
        const SizedBox(height: 10),

        // 4. Géneros
        if (genres.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: genres.map((g) => TvMovieGenreChip(label: g)).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // 5. Director y Elenco
        if (movie.formattedDirector case final director?) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_director.tr(),
            value: director,
          ),
          const SizedBox(height: 4),
        ],

        if (movie.formattedCast case final cast?) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_cast.tr(),
            value: cast,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
        ],

        // 6. Sinopsis: sin foco ni scroll, la letra se achica para que entre.
        Expanded(child: MovieSynopsisBlock(description: movie.description)),
      ],
    );
  }
}
