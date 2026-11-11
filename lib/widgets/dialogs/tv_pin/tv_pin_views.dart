part of '../tv_pin_dialog.dart';

/// Casillas del PIN y teclado numérico.
extension _TvPinDialogViews on _TvPinDialogState {
  Widget _buildPinBoxes(ColorScheme scheme) {
    // Las casillas son chips, sin "pozo" detrás: llenas, teñidas del acento;
    // la actual, con borde del acento; las vacías, tenues.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _digits.length;
          final isCurrent = index == _digits.length;

          return Container(
            width: 44,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            // Cristal: piezas de vidrio blanco como los botones (las llenas,
            // con el tinte del acento); la actual, además, borde del acento.
            decoration:
                moaiGlassButtonDecoration(
                  scheme,
                  focused: false,
                  highlighted: isFilled,
                  radius: 12,
                ).copyWith(
                  border: isCurrent
                      ? Border.all(color: scheme.primary, width: 1.5)
                      : null,
                ),
            alignment: Alignment.center,
            child: AnimatedScale(
              scale: isFilled ? 1.0 : (isCurrent ? 1.0 : 0.7),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: isFilled
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : (isCurrent
                        ? Container(
                            width: 3.0,
                            height: 18,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          )
                        : Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                              shape: BoxShape.circle,
                            ),
                          )),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildKeypad(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fila 0: 1, 2, 3
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(
              0,
              0,
              label: '1',
              scheme: scheme,
              onTap: () => _onDigitEntered('1'),
            ),
            _buildKey(
              0,
              1,
              label: '2',
              scheme: scheme,
              onTap: () => _onDigitEntered('2'),
            ),
            _buildKey(
              0,
              2,
              label: '3',
              scheme: scheme,
              onTap: () => _onDigitEntered('3'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 1: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(
              1,
              0,
              label: '4',
              scheme: scheme,
              onTap: () => _onDigitEntered('4'),
            ),
            _buildKey(
              1,
              1,
              label: '5',
              scheme: scheme,
              onTap: () => _onDigitEntered('5'),
            ),
            _buildKey(
              1,
              2,
              label: '6',
              scheme: scheme,
              onTap: () => _onDigitEntered('6'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 2: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(
              2,
              0,
              label: '7',
              scheme: scheme,
              onTap: () => _onDigitEntered('7'),
            ),
            _buildKey(
              2,
              1,
              label: '8',
              scheme: scheme,
              onTap: () => _onDigitEntered('8'),
            ),
            _buildKey(
              2,
              2,
              label: '9',
              scheme: scheme,
              onTap: () => _onDigitEntered('9'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 3: ⌫ (Borrar), 0, ✕ (Cancelar)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(
              3,
              0,
              icon: MoaiIcons.pinBackspace,
              isAction: true,
              // Naranja: borra el último dígito.
              iconColor: const Color(0xFFEA580C),
              scheme: scheme,
              onTap: _onBackspace,
            ),
            _buildKey(
              3,
              1,
              label: '0',
              scheme: scheme,
              onTap: () => _onDigitEntered('0'),
            ),
            _buildKey(
              3,
              2,
              icon: MoaiIcons.pinClose,
              isAction: true,
              // Rojo: cierra sin cambiar el PIN.
              iconColor: const Color(0xFFDC2626),
              scheme: scheme,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(
    int r,
    int c, {
    String? label,
    IconData? icon,
    bool isAction = false,
    Color? iconColor,
    required ColorScheme scheme,
    required VoidCallback onTap,
  }) {
    final focusNode = _focusGrid[r][c];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Focus(
        focusNode: focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowLeft) {
            _moveFocus(r, c, 0, -1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _moveFocus(r, c, 0, 1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            _moveFocus(r, c, -1, 0);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            if (r == 3) {
              _cancelBtnFocus.requestFocus();
            } else {
              _moveFocus(r, c, 1, 0);
            }
            return KeyEventResult.handled;
          }

          if (TvKeyHandler.isActionKey(key)) {
            onTap();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;

            // Teclas como los botones de los encabezados. Borrar y ✕:
            // blancas como los números, con el ícono en su color (naranja y
            // rojo).
            final fg = isFocused
                ? scheme.onPrimary
                : (iconColor ?? scheme.onSurface);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 72,
                  height: 40,
                  decoration: moaiGlassButtonDecoration(
                    scheme,
                    focused: isFocused,
                    radius: 12,
                  ),
                  alignment: Alignment.center,
                  child: label != null
                      ? Text(label, style: MoaiText.body(context, color: fg))
                      : Icon(icon, color: fg, size: MoaiIconSizes.md),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
