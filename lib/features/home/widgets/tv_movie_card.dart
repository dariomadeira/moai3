import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:reicons/reicons.dart';

/// Tarjeta de película Moiamov para Smart TV con soporte D-Pad.
class TvMovieCard extends StatefulWidget {
  final MovieItem movie;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final bool Function()? onKeyLeft;
  final bool Function()? onKeyRight;

  const TvMovieCard({
    super.key,
    required this.movie,
    this.focusNode,
    required this.onTap,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyLeft,
    this.onKeyRight,
  });

  @override
  State<TvMovieCard> createState() => _TvMovieCardState();
}

class _TvMovieCardState extends State<TvMovieCard> {
  bool _isFocused = false;

  IconData get _cardIcon {
    if (widget.movie.isTrailer) return ReiconIcons.reel;
    if (widget.movie.isSeries) return ReiconIcons.clapperboardText;
    return ReiconIcons.videoFrame2;
  }

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant TvMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = _isFocused || (widget.focusNode?.hasFocus ?? false);
    final poster = widget.movie.poster;
    final cardIcon = _cardIcon;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (key == LogicalKeyboardKey.arrowRight) {
            if (event is KeyRepeatEvent) return KeyEventResult.handled;
            if (widget.onKeyRight != null && widget.onKeyRight!()) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (event is KeyRepeatEvent) return KeyEventResult.handled;
            if (widget.onKeyLeft != null && widget.onKeyLeft!()) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            if (widget.onKeyUp != null) {
              widget.onKeyUp!();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (widget.onKeyDown != null) {
              widget.onKeyDown!();
              return KeyEventResult.handled;
            }
          } else if (TvKeyHandler.isActionKey(key)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode?.requestFocus();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.48),
              width: isFocused ? 2.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (poster != null && poster.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: poster,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          fadeInDuration: const Duration(milliseconds: 180),
                          fadeOutDuration: const Duration(milliseconds: 180),
                          placeholder: (context, url) => Container(
                            color: scheme.surfaceContainerLowest,
                            child: Icon(
                              cardIcon,
                              size: 40,
                              color: scheme.outline,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: scheme.surfaceContainerLowest,
                            child: Icon(
                              cardIcon,
                              size: 40,
                              color: scheme.outline,
                            ),
                          ),
                        )
                      else
                        Container(
                          color: scheme.surfaceContainerLowest,
                          child: Icon(
                            cardIcon,
                            size: 40,
                            color: scheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    widget.movie.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isFocused ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
