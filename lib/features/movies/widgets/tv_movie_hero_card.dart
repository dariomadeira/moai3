import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';
import 'package:moai3/utils/image_decode.dart';

/// Tarjeta visual cinematográfica 16:9 para la pantalla de detalle de películas en Smart TV.
class TvMovieHeroCard extends StatefulWidget {
  final String? imageUrl;
  final List<String> imageUrls;
  final String movieTitle;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;
  final String? playLabel;
  final bool isLoading;
  final VoidCallback? onArrowLeft;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onArrowRight;

  /// Alto del botón Reproducir.
  static const double playButtonSize = 32;

  const TvMovieHeroCard({
    super.key,
    this.imageUrl,
    this.imageUrls = const [],
    required this.movieTitle,
    this.playLabel,
    this.isLoading = false,
    this.focusNode,
    this.onPressed,
    this.onArrowLeft,
    this.onArrowUp,
    this.onArrowDown,
    this.onArrowRight,
  });

  @override
  State<TvMovieHeroCard> createState() => _TvMovieHeroCardState();
}

class _TvMovieHeroCardState extends State<TvMovieHeroCard> {
  bool _isFocused = false;
  int _currentIndex = 0;
  Timer? _rotationTimer;
  ModalRoute<Object?>? _route;

  List<String> get _effectiveImages {
    final list = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();
    if (list.isNotEmpty) return list;
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) {
      return [widget.imageUrl!];
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
    _startTimer();
  }

  void _startTimer() {
    _rotationTimer?.cancel();
    final images = _effectiveImages;
    if (images.length > 1) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        // Tapada por otra pantalla (p. ej. el reproductor): no repinta.
        if (!mounted || !(_route?.isCurrent ?? true)) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % images.length;
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void didUpdateWidget(covariant TvMovieHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
    if (widget.imageUrls != oldWidget.imageUrls ||
        widget.imageUrl != oldWidget.imageUrl) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final frame = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _isFocused
            ? scheme.primary
            : Colors.white.withValues(alpha: 0.14),
        width: _isFocused ? 2 : 1.0,
      ),
    );

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.arrowLeft && widget.onArrowLeft != null) {
          widget.onArrowLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight &&
            widget.onArrowRight != null) {
          widget.onArrowRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && widget.onArrowUp != null) {
          widget.onArrowUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onArrowDown != null) {
          widget.onArrowDown!();
          return KeyEventResult.handled;
        }
        if (TvKeyHandler.isActionKey(key)) {
          widget.onPressed?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode?.requestFocus();
          widget.onPressed?.call();
        },
        child: AnimatedScale(
          scale: _isFocused ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            // El borde va pintado encima de la imagen (como en [MoaiGlass]):
            // no ocupa lugar y el foco no mueve la foto.
            foregroundDecoration: frame,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Carrusel dinámico de fotogramas de la película. En su
                  // capa: el fundido cada 4 s no repinta el resto.
                  RepaintBoundary(child: _buildImageCarousel(scheme)),

                  // Viñeta degradada cinemática
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Reproducir abajo a la izquierda: el mismo botón que la
                  // tarjeta grande del Inicio (vidrio sin foco; con foco, el
                  // de toda la app).
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: MoaiPillButton(
                      kind: MoaiPillButtonKind.glass,
                      size: TvMovieHeroCard.playButtonSize,
                      icon: MoaiIcons.vodPlay,
                      label: widget.isLoading
                          ? LocaleKeys.movies_loading.tr()
                          : widget.playLabel ?? LocaleKeys.movies_play.tr(),
                      loading: widget.isLoading,
                      selected: _isFocused,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(ColorScheme scheme) {
    // Sin imagen: un "pozo" tenue en vez de un bloque opaco.
    final emptyColor = Colors.white.withValues(alpha: 0.04);
    final images = _effectiveImages;
    if (images.isEmpty) {
      return Container(
        color: emptyColor,
        child: Center(
          child: Icon(
            MoaiIcons.vodMovie,
            size: MoaiIconSizes.hero,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final currentUrl = images[_currentIndex % images.length];

    return LayoutBuilder(
      builder: (context, constraints) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _buildImage(
          context,
          scheme,
          currentUrl,
          emptyColor,
          constraints,
        ),
      ),
    );
  }

  Widget _buildImage(
    BuildContext context,
    ColorScheme scheme,
    String currentUrl,
    Color emptyColor,
    BoxConstraints constraints,
  ) {
    return CachedNetworkImage(
      key: ValueKey<String>(currentUrl),
      imageUrl: currentUrl,
      cacheManager: MovieImageCache.photos,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      // Las fotos vienen de hasta 4096 px y rotan cada 4 s: se decodifican
      // al tamaño de la tarjeta, no enteras.
      memCacheWidth: constraints.hasBoundedWidth && constraints.hasBoundedHeight
          ? coverDecodeWidth(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            )
          : null,
      placeholder: (_, _) => Container(
        color: emptyColor,
        child: Center(
          child: Icon(
            MoaiIcons.vodMovie,
            size: MoaiIconSizes.hero,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        color: emptyColor,
        child: Center(
          child: Icon(
            MoaiIcons.vodMovie,
            size: MoaiIconSizes.hero,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
