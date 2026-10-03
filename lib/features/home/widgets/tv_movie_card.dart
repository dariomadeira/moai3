import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tarjeta de película optimizada para Smart TV con soporte D-Pad (SPEC-38).
class TvMovieCard extends StatefulWidget {
  final Movie movie;
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
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? scheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Poster Image
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (widget.movie.posterPath != null &&
                          widget.movie.posterPath!.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: widget.movie.posterPath!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: scheme.surfaceContainerLowest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: scheme.surfaceContainerLowest,
                            child: Icon(Icons.movie, size: 40, color: scheme.outline),
                          ),
                        )
                      else
                        Container(
                          color: scheme.surfaceContainerLowest,
                          child: Icon(Icons.movie, size: 40, color: scheme.outline),
                        ),

                      // Rating Badge (top right)
                      if (widget.movie.voteAverage > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 13,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.movie.voteAverage.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Title & Release Date Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isFocused ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (widget.movie.releaseDate != null)
                        Text(
                          widget.movie.releaseDate!,
                          maxLines: 1,
                          style: MoaiText.body(
                            context,
                            fontSize: 9,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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
