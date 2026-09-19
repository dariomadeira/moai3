import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/alphabet_letter_card.dart';

import 'package:moai3/widgets/lists/tv_windowed_list.dart';

class AlphabetDeleteCard extends StatefulWidget {
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const AlphabetDeleteCard({
    super.key,
    required this.onTap,
    this.focusNode,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<AlphabetDeleteCard> createState() => _AlphabetDeleteCardState();
}

class _AlphabetDeleteCardState extends State<AlphabetDeleteCard> {
  bool _isFocused = false;
  bool _isKeyDown = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          final key = event.logicalKey;
          final isActionButton =
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space;

          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            // Nunca L/R: no cambiar de panel con filtro activo.
            if (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.arrowLeft) {
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowUp) {
              widget.onKeyUp?.call();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowDown) {
              widget.onKeyDown?.call();
              return KeyEventResult.handled;
            } else if (isActionButton) {
              if (event is KeyDownEvent) {
                _isKeyDown = true;
              }
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent) {
            if (isActionButton) {
              if (_isKeyDown) {
                _isKeyDown = false;
                widget.onTap();
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _isFocused ? scheme.errorContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Symbols.delete,
                size: 16,
                color: _isFocused ? scheme.onErrorContainer : scheme.error,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AlphabetJumpPanel extends StatelessWidget {
  final List<String> letters;
  final List<FocusNode>? focusNodes;
  final ValueChanged<String> onLetterTap;
  final bool showDeleteTile;
  final VoidCallback? onDeleteTap;

  const AlphabetJumpPanel({
    super.key,
    required this.letters,
    this.focusNodes,
    required this.onLetterTap,
    this.showDeleteTile = false,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = showDeleteTile ? ['__delete__', ...letters] : letters;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 27),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final extent = TvLayoutConstants.alphabetItemHeight;
          final computedWindowSize =
              (maxH > 0 && maxH.isFinite) ? (maxH / extent).floor().clamp(4, 30) : 10;

          return TvWindowedList<String>(
            items: items,
            windowSize: computedWindowSize,
            itemExtent: extent,
            itemBuilder: (context, item, focusNode, localIndex, globalIndex, onKeyUp, onKeyDown) {
              if (showDeleteTile && globalIndex == 0) {
                return AlphabetDeleteCard(
                  key: const ValueKey('alpha-delete'),
                  focusNode: focusNode,
                  onTap: onDeleteTap ?? () {},
                  onKeyUp: onKeyUp,
                  onKeyDown: onKeyDown,
                );
              }

              final letter = item;
              return AlphabetLetterCard(
                key: ValueKey('alpha-$letter'),
                letter: letter,
                focusNode: focusNode,
                onTap: () => onLetterTap(letter),
                onKeyUp: onKeyUp,
                onKeyDown: onKeyDown,
              );
            },
          );
        },
      ),
    );
  }
}

