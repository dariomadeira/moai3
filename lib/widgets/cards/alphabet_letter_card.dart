import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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
          final isActionButton = TvKeyHandler.isActionKey(key);

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
              width: 26,
              height: 26,
              // En cristal el foco es el de los botones (acento con brillo y
              // halo); en reposo la letra va suelta.
              decoration: MoaiGlassScope.enabledOf(context) && _isFocused
                  ? moaiGlassButtonDecoration(scheme, focused: true, radius: 13)
                  : BoxDecoration(
                      color: _isFocused ? scheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
              alignment: Alignment.center,
              child: Text(
                widget.letter,
                style: MoaiText.body(
                  context,
                  fontSize: 13,
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
