import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tarjeta reutilizable de estado vacío para listas en pantallas TV.
///
/// Encapsula la gestión de foco D-pad, borde animado y presentación estilizada.
class TvEmptyStateCard extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String message;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;
  final VoidCallback? onTap;

  const TvEmptyStateCard({
    super.key,
    required this.focusNode,
    required this.icon,
    required this.message,
    this.onFocusUp,
    this.onFocusDown,
    this.onFocusLeft,
    this.onFocusRight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp && onFocusUp != null) {
          onFocusUp!.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && onFocusDown != null) {
          onFocusDown!.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && onFocusLeft != null) {
          onFocusLeft!.call();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && onFocusRight != null) {
          onFocusRight!.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFocused
                    ? scheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused ? scheme.primary : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: isFocused
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: MoaiText.body(
                        context,
                        color: isFocused
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
