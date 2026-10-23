import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/features/movies/widgets/tv_movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/features/movies/screens/movie_player_screen.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:reicons/reicons.dart';

/// Pantalla de detalle de película para Smart TV con diseño Split Cinemático 60/40.
class MovieDetailScreen extends StatefulWidget {
  final MovieItem movie;

  const MovieDetailScreen({super.key, required this.movie});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'movie_detail_back');
  final FocusNode _favFocusNode = FocusNode(debugLabel: 'movie_detail_fav');
  final FocusNode _heroFocusNode = FocusNode(debugLabel: 'movie_detail_hero');

  bool _isFavorite = false;
  bool _isLoadingStream = false;
  MovieWatchProgress? _watchProgress;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _heroFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadProgress() async {
    final progress = await MovieProgressService.getProgress(widget.movie.contentId);
    if (mounted) {
      setState(() => _watchProgress = progress);
    }
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    _favFocusNode.dispose();
    _heroFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onPlayPressed() async {
    if (_isLoadingStream) return;
    setState(() => _isLoadingStream = true);

    try {
      final stream = await MoiamovApiService.instance.resolveMovieStream(
        movie: widget.movie,
      );

      if (!mounted) return;

      if (stream == null || stream.directHlsUrl.isEmpty) {
        final errorMsg = MoiamovApiService.instance.lastResolutionError ??
            'No se pudo conectar con el servidor de streaming.';
        MoaiSnackBar.showError(
          context,
          message: errorMsg,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      final savedProgress = await MovieProgressService.getProgress(widget.movie.contentId);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MoviePlayerScreen(
            movie: widget.movie,
            stream: stream,
            initialPositionSeconds: savedProgress?.positionSeconds,
          ),
        ),
      );

      if (mounted) {
        await _loadProgress();
        if (mounted) {
          _heroFocusNode.requestFocus();
        }
      }
    } catch (e) {
      if (mounted) {
        MoaiSnackBar.showError(
          context,
          message: 'Error al iniciar reproducción: $e',
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingStream = false);
      }
    }
  }

  void _toggleFavorite() {
    setState(() => _isFavorite = !_isFavorite);
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.brightness == Brightness.dark
                ? [
                    Color.lerp(
                      scheme.surfaceContainerHigh,
                      scheme.primary,
                      0.08,
                    )!,
                    scheme.surfaceContainerLow,
                  ]
                : [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/movie.png',
                  fit: BoxFit.cover,
                ),
              ),
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
                          titles: const ['Película'],
                          icons: const [ReiconIcons.clapperboardOpen],
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
                                      'Película',
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
                                    ReiconIcons.clapperboardOpen,
                                    size: 20,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          buildExpandedContent: (index, title) {
                            final ambientUrl = movie.ambientBackdrop;

                            return ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(15),
                                bottomRight: Radius.circular(15),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Imagen ambiental difuminada en la esquina superior derecha
                                  // (solo si hay más de 1 imagen para no duplicar con la tarjeta de abajo)
                                  if (ambientUrl != null &&
                                      ambientUrl.isNotEmpty)
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
                                                      movie
                                                          .stageImages
                                                          .isNotEmpty
                                                      ? movie.stageImages.first
                                                      : movie.effectiveBackdrop,
                                                  imageUrls: movie.stageImages,
                                                  movieTitle: movie.name,
                                                  isLoading: _isLoadingStream,
                                                  playLabel: (_watchProgress?.canResume == true)
                                                      ? 'Reanudar'
                                                      : 'Reproducir',
                                                  onPressed: _onPlayPressed,
                                                  onArrowLeft: _backFocusNode.requestFocus,
                                                  onArrowDown: _favFocusNode.requestFocus,
                                                  onArrowUp: _backFocusNode.requestFocus,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TvFocusButton(
                                                  focusNode: _favFocusNode,
                                                  label: _isFavorite
                                                      ? 'En Favoritos'
                                                      : 'Favorito',
                                                  icon: _isFavorite
                                                      ? ReiconFilledIcons.star
                                                      : ReiconIcons.star,
                                                  variant: _isFavorite
                                                      ? TvButtonVariant.tonal
                                                      : TvButtonVariant.surface,
                                                  height: 38,
                                                  fontSize: 13,
                                                  radius: 20,
                                                  onPressed: _toggleFavorite,
                                                  onArrowLeft: _backFocusNode.requestFocus,
                                                  onArrowUp: _heroFocusNode.requestFocus,
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
      ),
    );
  }

  Widget _buildAmbientBackdrop(BuildContext context, String imageUrl) {
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
        child: Opacity(
          opacity: 0.70,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
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
    final hasAlias =
        movie.alias != null &&
        movie.alias!.trim().isNotEmpty &&
        movie.alias!.trim().toLowerCase() != movie.name.trim().toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Título
        Text(
          movie.name,
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
            movie.alias!,
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

        // 3. Fila de metadatos rápidos (Puntuación, Año, Duración, Calidad) idénticos a los pills de TV
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_buildScorePill(context, scheme, movie) != null)
              _buildScorePill(context, scheme, movie)!,
            if (year != null && year.isNotEmpty)
              TvMetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: ReiconIcons.calendar,
                label: year,
              ),
            if (duration != null && duration.isNotEmpty)
              TvMetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: ReiconIcons.clockCircle,
                label: duration,
              ),
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: ReiconIcons.hd,
              label: '1080P HD',
            ),
            if (_watchProgress != null)
              if (_watchProgress!.isCompleted)
                TvMetaPill(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  foreground: const Color(0xFF34D399),
                  icon: ReiconFilledIcons.checkCircle,
                  label: 'Vista',
                )
              else if (_watchProgress!.canResume)
                TvMetaPill(
                  color: scheme.primary.withValues(alpha: 0.2),
                  foreground: scheme.primary,
                  icon: ReiconIcons.history,
                  label: '${(_watchProgress!.progressPercentage * 100).toInt()}% visto',
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
                'Director: ',
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
                'Elenco: ',
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
                'Sinopsis',
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    (movie.description != null &&
                            movie.description!.trim().isNotEmpty)
                        ? movie.description!
                        : 'Sin sinopsis disponible.',
                    style: MoaiText.body(
                      context,
                      fontSize: 13,
                      height: 1.35,
                      color: scheme.onSurface.withValues(alpha: 0.88),
                    ),
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

    final Color bg;
    final Color fg;

    if (val != null) {
      if (val > 7.0) {
        // > 7.0: Amarillo / Dorado
        bg = const Color(0xFFF59E0B).withValues(alpha: 0.22);
        fg = const Color(0xFFFBBF24);
      } else if (val >= 5.0) {
        // 5.0 a 7.0: Plata / Gris
        bg = const Color(0xFF94A3B8).withValues(alpha: 0.24);
        fg = const Color(0xFFE2E8F0);
      } else {
        // < 5.0: Rojo
        bg = const Color(0xFFEF4444).withValues(alpha: 0.24);
        fg = const Color(0xFFF87171);
      }
    } else {
      bg = scheme.tertiaryContainer;
      fg = scheme.onTertiaryContainer;
    }

    return TvMetaPill(
      color: bg,
      foreground: fg,
      icon: ReiconFilledIcons.star,
      label: scoreText,
    );
  }
}
