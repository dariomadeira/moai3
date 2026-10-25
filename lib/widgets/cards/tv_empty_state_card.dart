import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Tarjeta reutilizable de estado vacío para listas en pantallas TV.
///
/// Encapsula la gestión de foco D-pad, borde animado y presentación estilizada.
class TvEmptyStateCard extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String message;
  final String? subtitle;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
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
    this.subtitle,
    this.margin,
    this.padding,
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
            final content = _content(context, scheme, isFocused);
            // En cristal el foco es el de [MoaiGlass] (borde del acento y
            // tinte suave), igual que el resto de los componentes; en reposo
            // queda transparente.
            if (isFocused && MoaiGlassScope.enabledOf(context)) {
              return Padding(
                padding:
                    margin ??
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: MoaiGlass(
                  borderRadius: 16,
                  elevated: false,
                  solid: true,
                  focused: true,
                  padding: padding ?? const EdgeInsets.all(20),
                  child: content,
                ),
              );
            }
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:
                  margin ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              padding: padding ?? const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isFocused
                    ? scheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              // Borde del foco pintado encima: no ocupa espacio, así el
              // contenido no se mueve al enfocar.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused ? scheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme, bool isFocused) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: MoaiIconSizes.hero,
          color: isFocused ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              color: isFocused ? scheme.onSurface : scheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Center(
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
