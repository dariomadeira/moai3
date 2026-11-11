import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_focus_style.dart';
import 'package:moai3/theme/moai_text.dart';

class AlphabetLetterCard extends StatefulWidget {
  final String letter;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  /// Color del foco, como el de la sección en el rail (sin él, el acento).
  final Color? focusColor;

  const AlphabetLetterCard({
    super.key,
    required this.letter,
    required this.onTap,
    this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.focusColor,
  });

  @override
  State<AlphabetLetterCard> createState() => _AlphabetLetterCardState();
}

class _AlphabetLetterCardState extends State<AlphabetLetterCard> {
  // Al correrse la ventana de letras la ficha se vuelve a crear con el foco
  // ya puesto (sin aviso de cambio): se lee del nodo.
  late bool _isFocused = widget.focusNode?.hasFocus ?? false;
  bool _isKeyDown = false;

  @override
  void didUpdateWidget(covariant AlphabetLetterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final focused = _isFocused || (widget.focusNode?.hasFocus ?? false);

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
            // Sin animación, como el rail: al fundir el fondo la letra
            // blanca se perdía sobre el vidrio y el botón titilaba.
            child: Container(
              width: 26,
              height: 26,
              // El foco es el del rail (color sólido con brillo y halo); en
              // reposo la letra va suelta.
              decoration: focused
                  ? MoaiFocusStyle.decoration(scheme, color: widget.focusColor)
                  : null,
              alignment: Alignment.center,
              // Las mayúsculas no tienen parte de abajo: centradas en la
              // caja del texto quedan 1 punto altas.
              child: Transform.translate(
                offset: const Offset(0, 1),
                child: Text(
                  widget.letter,
                  style: MoaiText.body(
                    context,
                    fontSize: 13,
                    color: focused
                        ? (widget.focusColor != null
                              ? Colors.white
                              : scheme.onPrimary)
                        : scheme.onSurface,
                    fontWeight: focused ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
