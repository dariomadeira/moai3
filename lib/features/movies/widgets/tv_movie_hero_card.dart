import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

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
        if (!mounted) return;
        setState(() {
          _currentIndex = (_currentIndex + 1) % images.length;
        });
      });
    }
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isFocused
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.35),
                width: _isFocused ? 2.5 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Carrusel dinámico de fotogramas de la película
                  _buildImageCarousel(scheme),

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

                  // Botón delicado de Play abajo a la izquierda
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _isFocused
                            ? scheme.primary
                            : Colors.black.withValues(alpha: 0.55),
                        border: Border.all(
                          color: _isFocused
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.32),
                          width: _isFocused ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isLoading) ...[
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isFocused ? scheme.onPrimary : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              LocaleKeys.movies_loading.tr(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isFocused ? scheme.onPrimary : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              MoaiIcons.vodPlay,
                              size: MoaiIconSizes.sm,
                              color: _isFocused ? scheme.onPrimary : Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.playLabel ?? LocaleKeys.movies_play.tr(),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _isFocused ? scheme.onPrimary : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ],
                      ),
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
    final images = _effectiveImages;
    if (images.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHigh,
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: CachedNetworkImage(
        key: ValueKey<String>(currentUrl),
        imageUrl: currentUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => Container(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: Icon(
              MoaiIcons.vodMovie,
              size: MoaiIconSizes.hero,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        errorWidget: (_, _, _) => Container(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: Icon(
              MoaiIcons.vodMovie,
              size: MoaiIconSizes.hero,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
