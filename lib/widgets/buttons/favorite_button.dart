import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';

class FavoriteButton extends StatefulWidget {
  final Channel channel;
  final FocusNode focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const FavoriteButton({
    super.key,
    required this.channel,
    required this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFav = context.select<FavoritesProvider, bool>(
      (state) => state.isFavorite(widget.channel),
    );

    final Color bgColor;
    final Color iconColor;

    if (_isFocused) {
      bgColor = scheme.primary;
      iconColor = scheme.onPrimary;
    } else if (isFav) {
      bgColor = scheme.primaryContainer;
      iconColor = scheme.onPrimaryContainer;
    } else {
      bgColor = scheme.surface;
      iconColor = scheme.onSurfaceVariant;
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() {
          _isFocused = focused;
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (widget.onKeyLeft != null) {
              widget.onKeyLeft!();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowRight) {
            if (widget.onKeyRight != null) {
              widget.onKeyRight!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (widget.onKeyDown != null) {
              widget.onKeyDown!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            if (widget.onKeyUp != null) {
              widget.onKeyUp!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            context.read<FavoritesProvider>().toggleFavorite(widget.channel);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          context.read<FavoritesProvider>().toggleFavorite(widget.channel);
        },
        child: AnimatedScale(
          scale: _isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

