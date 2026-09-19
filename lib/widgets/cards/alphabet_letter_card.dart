import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';

class AlphabetLetterCard extends StatefulWidget {
  final String letter;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const AlphabetLetterCard({
    super.key,
    required this.letter,
    required this.onTap,
    this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<AlphabetLetterCard> createState() => _AlphabetLetterCardState();
}

class _AlphabetLetterCardState extends State<AlphabetLetterCard> {
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
            // Nunca L/R con filtro activo (no cambiar de panel).
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
                color: _isFocused ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.letter,
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  color: _isFocused ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: _isFocused ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

