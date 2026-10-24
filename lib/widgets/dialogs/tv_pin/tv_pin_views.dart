part of '../tv_pin_dialog.dart';

/// Casillas del PIN y teclado numérico.
extension _TvPinDialogViews on _TvPinDialogState {
  Widget _buildPinBoxes(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < _digits.length;
          final isCurrent = index == _digits.length;

          final Color boxBg;
          if (isFilled) {
            boxBg = scheme.primaryContainer;
          } else if (isCurrent) {
            boxBg = scheme.surface;
          } else {
            boxBg = scheme.surface.withValues(alpha: 0.5);
          }

          final boxBorderColor = isCurrent
              ? scheme.primary.withValues(alpha: 0.7)
              : scheme.outlineVariant.withValues(alpha: isFilled ? 0.45 : 0.25);

          return Container(
            width: 44,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: boxBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: boxBorderColor,
              ),
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
                            color: scheme.outlineVariant.withValues(alpha: 0.6),
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
            _buildKey(0, 0, label: '1', scheme: scheme, onTap: () => _onDigitEntered('1')),
            _buildKey(0, 1, label: '2', scheme: scheme, onTap: () => _onDigitEntered('2')),
            _buildKey(0, 2, label: '3', scheme: scheme, onTap: () => _onDigitEntered('3')),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 1: 4, 5, 6
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(1, 0, label: '4', scheme: scheme, onTap: () => _onDigitEntered('4')),
            _buildKey(1, 1, label: '5', scheme: scheme, onTap: () => _onDigitEntered('5')),
            _buildKey(1, 2, label: '6', scheme: scheme, onTap: () => _onDigitEntered('6')),
          ],
        ),
        const SizedBox(height: 6),
        // Fila 2: 7, 8, 9
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(2, 0, label: '7', scheme: scheme, onTap: () => _onDigitEntered('7')),
            _buildKey(2, 1, label: '8', scheme: scheme, onTap: () => _onDigitEntered('8')),
            _buildKey(2, 2, label: '9', scheme: scheme, onTap: () => _onDigitEntered('9')),
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
              scheme: scheme,
              onTap: _onBackspace,
            ),
            _buildKey(3, 1, label: '0', scheme: scheme, onTap: () => _onDigitEntered('0')),
            _buildKey(
              3,
              2,
              icon: MoaiIcons.pinClose,
              isAction: true,
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

            final Color bg;
            final Color fg;

            if (isFocused) {
              bg = scheme.primary;
              fg = scheme.onPrimary;
            } else if (isAction) {
              bg = scheme.primaryContainer;
              fg = scheme.onPrimaryContainer;
            } else {
              bg = scheme.surface;
              fg = scheme.onSurface;
            }

            final borderColor = isFocused
                ? scheme.onPrimary.withValues(alpha: 0.6)
                : scheme.outlineVariant.withValues(alpha: 0.35);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: 72,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: label != null
                      ? Text(
                          label,
                          style: MoaiText.body(
                            context,
                            color: fg,
                          ),
                        )
                      : Icon(
                          icon,
                          color: fg,
                          size: MoaiIconSizes.md,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
