import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/features/movies/widgets/tv_movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/image_decode.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/titan_ranger_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';

/// Pantalla de detalle de película para Smart TV con diseño Split Cinemático 60/40.
class MovieDetailScreen extends StatefulWidget {
  final MovieItem movie;

  /// Resuelve el stream al reproducir; por defecto [MoiamovApiService]. Los
  /// tests lo reemplazan para no salir a la red.
  final Future<ResolvedPlayStream?> Function(MovieItem movie)? resolveStream;

  const MovieDetailScreen({super.key, required this.movie, this.resolveStream});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'movie_detail_back');
  final FocusNode _watchlistFocusNode = FocusNode(
    debugLabel: 'movie_detail_watchlist',
  );
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'movie_detail_hero');
  final FocusNode _synopsisFocusNode = FocusNode(
    debugLabel: 'movie_detail_synopsis',
  );
  final ScrollController _synopsisScroll = ScrollController();

  bool _inWatchlist = false;
  bool _isLoadingStream = false;
  MovieWatchProgress? _watchProgress;

  /// La sinopsis no entra entera: se puede enfocar y scrollear con ↑/↓.
  bool _synopsisScrollable = false;
  bool _synopsisFocused = false;

  static const double _synopsisStep = 60;

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
    // mira el detalle, no al tocar Reproducir. Una vez por arranque.
    unawaited(TitanRangerService.init());
    if (!_isTrailer) {
      _loadProgress();
      _loadWatchlist();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _heroFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadWatchlist() async {
    final watchlist = MovieWatchlistService.instance;
    await watchlist.ensureLoaded();
    if (mounted) {
      setState(() => _inWatchlist = watchlist.contains(widget.movie.contentId));
    }
  }

  Future<void> _loadProgress() async {
    final progress = await MovieProgressService.getProgress(
      widget.movie.contentId,
    );
    if (mounted) {
      setState(() => _watchProgress = progress);
    }
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    _watchlistFocusNode.dispose();
    _heroFocusNode.dispose();
    _synopsisFocusNode.dispose();
    _synopsisScroll.dispose();
    super.dispose();
  }

  /// ← desde la Hero o Marcar como interesante: a la sinopsis si se puede scrollear; si no,
  /// al botón atrás.
  void _focusLeftOfActions() {
    (_synopsisScrollable ? _synopsisFocusNode : _backFocusNode).requestFocus();
  }

  bool _onSynopsisMetrics(ScrollMetricsNotification n) {
    final scrollable = n.metrics.maxScrollExtent > 0;
    if (scrollable != _synopsisScrollable) {
      // Llega durante el layout: el cambio va al frame siguiente.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _synopsisScrollable = scrollable);
      });
    }
    return false;
  }

  KeyEventResult _onSynopsisKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      if (!_synopsisScroll.hasClients) return KeyEventResult.handled;
      final position = _synopsisScroll.position;
      final delta = key == LogicalKeyboardKey.arrowDown
          ? _synopsisStep
          : -_synopsisStep;
      _synopsisScroll.animateTo(
        (position.pixels + delta).clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _backFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _heroFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Con algo visto (en progreso), pregunta si retomar o empezar de nuevo.
  /// `null`: canceló (atrás).
  Future<bool?> _askResume(MovieWatchProgress progress) {
    final fromStartFocus = FocusNode(debugLabel: 'resume_from_start');
    final resumeFocus = FocusNode(debugLabel: 'resume_resume');
    return showTvGeneralDialog<bool>(
      context: context,
      barrierLabel: 'ResumeOrRestart',
      builder: (dialogContext) => TvDialog(
        icon: MoaiIcons.vodResume,
        title: LocaleKeys.movies_resume_dialog_title.tr(),
        subtitle: LocaleKeys.movies_resume_dialog_desc.tr(
          namedArgs: {
            'time': formatPlayerTime(
              Duration(seconds: progress.positionSeconds),
            ),
          },
        ),
        actions: [
          TvDialogButton(
            label: LocaleKeys.movies_resume_from_start.tr(),
            focusNode: fromStartFocus,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            onKeyRight: resumeFocus.requestFocus,
          ),
          TvDialogButton(
            label: LocaleKeys.movies_resume.tr(),
            variant: TvDialogButtonVariant.primary,
            focusNode: resumeFocus,
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            onKeyLeft: fromStartFocus.requestFocus,
          ),
        ],
      ),
    ).whenComplete(() {
      fromStartFocus.dispose();
      resumeFocus.dispose();
    });
  }

  Future<void> _onPlayPressed() async {
    if (_isLoadingStream) return;

    // Retomar o desde el principio (los adelantos no tienen progreso).
    int? startAt;
    final progress = _watchProgress;
    if (!_isTrailer && progress != null && progress.canResume) {
      final resume = await _askResume(progress);
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

    if (!_isTrailer) {
      await _loadProgress();
      // Si quedó vista, salió de Interesantes: el botón lo refleja.
      await _loadWatchlist();
    }
    if (mounted) _heroFocusNode.requestFocus();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final movie = widget.movie;

    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        TvBackPill(
                          focusNode: _backFocusNode,
                          onKeyRight: _heroFocusNode.requestFocus,
                          onKeyDown: _heroFocusNode.requestFocus,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: TvAccordionRowPreview(
                        panelCount: 1,
                        activeIndex: 0,
                        colors: [scheme.surface.withValues(alpha: 0.85)],
                        titles: [_tabTitle],
                        icons: const [MoaiIcons.vodPoster],
                        onPanelTap: (_) {},
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
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Icon(
                                  MoaiIcons.vodPoster,
                                  size: MoaiIconSizes.md,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.85,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        buildExpandedContent: (index, title) {
                          // Sólo si la Hero no la repite (con una única
                          // imagen la muestra ella).
                          final ambientUrl = movie.ambientBackdrop;
                          final showAmbient =
                              ambientUrl != null &&
                              ambientUrl.isNotEmpty &&
                              !movie.stageImages.contains(ambientUrl);

                          return ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(15),
                              bottomRight: Radius.circular(15),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Imagen ambiental difuminada en la esquina superior derecha
                                if (showAmbient)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    width: 525,
                                    height: 285,
                                    child: IgnorePointer(
                                      child: _buildAmbientBackdrop(
                                        context,
                                        ambientUrl,
                                      ),
                                    ),
                                  ),

                                // Contenido en primer plano
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Columna Izquierda: Información de la película y acciones
                                      Expanded(
                                        flex: 6,
                                        child: _buildInfoColumn(
                                          context,
                                          scheme,
                                          movie,
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      // Columna Derecha: Backdrop 16:9 alineado arriba con Play central
                                      Expanded(
                                        flex: 5,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const Spacer(),
                                            AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: TvMovieHeroCard(
                                                focusNode: _heroFocusNode,
                                                imageUrl:
                                                    movie.stageImages.isNotEmpty
                                                    ? movie.stageImages.first
                                                    : movie.effectiveBackdrop,
                                                imageUrls: movie.stageImages,
                                                movieTitle: movie.displayName,
                                                isLoading: _isLoadingStream,
                                                // Siempre "Reproducir": si hay
                                                // dónde retomar, se pregunta al
                                                // tocarlo.
                                                playLabel: LocaleKeys
                                                    .movies_play
                                                    .tr(),
                                                onPressed: _onPlayPressed,
                                                onArrowLeft:
                                                    _focusLeftOfActions,
                                                onArrowDown: _isTrailer
                                                    ? null
                                                    : _watchlistFocusNode
                                                          .requestFocus,
                                                onArrowUp:
                                                    _backFocusNode.requestFocus,
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
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TvFocusButton(
                                                  focusNode:
                                                      _watchlistFocusNode,
                                                  label: _inWatchlist
                                                      ? LocaleKeys
                                                            .movies_watchlist_added
                                                            .tr()
                                                      : LocaleKeys
                                                            .movies_watchlist_add
                                                            .tr(),
                                                  icon: MoaiIcons.vodWatchlist,
                                                  variant: _inWatchlist
                                                      ? TvButtonVariant.tonal
                                                      : TvButtonVariant.surface,
                                                  height: 38,
                                                  fontSize: 13,
                                                  radius: 20,
                                                  onPressed: _toggleWatchlist,
                                                  onArrowLeft:
                                                      _focusLeftOfActions,
                                                  onArrowUp: _heroFocusNode
                                                      .requestFocus,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Foto difuminada arriba a la derecha. Va en su propia capa: la Hero de al
  /// lado cambia de foto cada 4 s y, sin esto, las máscaras se repintaban en
  /// cada cuadro del fundido.
  Widget _buildAmbientBackdrop(BuildContext context, String imageUrl) {
    return RepaintBoundary(child: _buildAmbientMasks(context, imageUrl));
  }

  Widget _buildAmbientMasks(BuildContext context, String imageUrl) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        // Desvanecimiento suave en X: el borde izquierdo se vuelve 100% transparente
        return const LinearGradient(
          colors: [Colors.transparent, Colors.white],
          stops: [0.0, 0.40],
        ).createShader(bounds);
      },
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // Desvanecimiento suave en Y: el borde inferior se vuelve 100% transparente
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.transparent],
            stops: [0.45, 1.0],
          ).createShader(bounds);
        },
        // La transparencia va en la imagen misma (sin una capa más de
        // Opacity).
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          color: Colors.white.withValues(alpha: 0.70),
          colorBlendMode: BlendMode.modulate,
          // Al tamaño del recuadro (525×285), no al de la foto (hasta
          // 4096 px).
          memCacheWidth: coverDecodeWidth(
            width: 525,
            height: 285,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          ),
          alignment: Alignment.centerRight,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    ColorScheme scheme,
    MovieItem movie,
  ) {
    final year = movie.formattedYear;
    final duration = movie.formattedDuration;
    final genres = movie.genreList;
    final scorePill = _buildScorePill(context, scheme, movie);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En un tráiler, sin la marca "(Tráiler)" que trae el catálogo.
    final alias = MovieItem.withoutTrailerTag(movie.alias ?? '');
    final hasAlias =
        alias.isNotEmpty &&
        alias.toLowerCase() !=
            MovieItem.withoutTrailerTag(movie.name).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Título
        Text(
          movie.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.display(
            context,
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),

        // 2. Título original / Alias
        if (hasAlias) ...[
          Text(
            alias,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],

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
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.vodReleaseDate,
                label: year,
              ),
            // La duración de un tráiler en el catálogo es la de la película.
            if (!movie.isTrailer && duration != null && duration.isNotEmpty)
              TvMetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.vodDuration,
                label: duration,
              ),
            if (_watchProgress != null)
              if (_watchProgress!.isCompleted)
                TvMetaPill(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  foreground: dark
                      ? const Color(0xFF34D399)
                      : const Color(0xFF047857),
                  icon: MoaiIcons.vodWatched,
                  label: LocaleKeys.movies_watched.tr(),
                )
              else if (_watchProgress!.canResume)
                TvMetaPill(
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
        if (movie.director != null && movie.director!.trim().isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.movies_director.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  movie.director!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        if (movie.actorDisplay != null &&
            movie.actorDisplay!.trim().isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.movies_cast.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: Text(
                  movie.actorDisplay!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        // 6. Sinopsis con scroll
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocaleKeys.movies_synopsis.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              // Si no entra, se enfoca con ← desde la Hero y ↑/↓ la scrollean.
              Expanded(
                child: Focus(
                  focusNode: _synopsisFocusNode,
                  canRequestFocus: _synopsisScrollable,
                  skipTraversal: !_synopsisScrollable,
                  onFocusChange: (f) => setState(() => _synopsisFocused = f),
                  onKeyEvent: _onSynopsisKey,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: _onSynopsisMetrics,
                          child: SingleChildScrollView(
                            controller: _synopsisScroll,
                            child: Text(
                              (movie.description != null &&
                                      movie.description!.trim().isNotEmpty)
                                  ? movie.description!
                                  : LocaleKeys.movies_synopsis_empty.tr(),
                              style: MoaiText.body(
                                context,
                                fontSize: 13,
                                height: 1.35,
                                color: scheme.onSurface.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Marco de foco por fuera del texto: no lo corre.
                      Positioned(
                        left: -8,
                        top: -4,
                        right: -8,
                        bottom: -4,
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _synopsisFocused
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildScorePill(
    BuildContext context,
    ColorScheme scheme,
    MovieItem movie,
  ) {
    final scoreText = movie.formattedScore;
    if (scoreText == null || scoreText.isEmpty) return null;

    final val = double.tryParse(movie.score ?? '');
    // En tema claro, el mismo tono más oscuro para que se lea sobre el fondo.
    final dark = Theme.of(context).brightness == Brightness.dark;

    final Color bg;
    final Color fg;

    if (val != null) {
      if (val > 7.0) {
        // > 7.0: Amarillo / Dorado
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.22);
        fg = dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      } else if (val >= 5.0) {
        // 5.0 a 7.0: Plata / Gris
        bg = const Color(0xFF94A3B8).withValues(alpha: 0.24);
        fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
      } else {
        // < 5.0: Rojo
        bg = const Color(0xFFEF4444).withValues(alpha: 0.24);
        fg = dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
      }
    } else {
      bg = scheme.tertiaryContainer;
      fg = scheme.onTertiaryContainer;
    }

    return TvMetaPill(
      color: bg,
      foreground: fg,
      icon: MoaiIcons.vodRatingFilled,
      label: scoreText,
    );
  }
}
