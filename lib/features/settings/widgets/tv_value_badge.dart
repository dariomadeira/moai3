import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Una píldora/insignia de valor para mostrar información destacada en las filas TV.
/// Sigue el diseño con tono de acento translúcido en reposo y borde del color de acento al enfocar la fila.
class TvValueBadge extends StatelessWidget {
  final String text;
  final bool isFocused;
  final Color? accentColor;
  final TextStyle? textStyle;

  const TvValueBadge({
    super.key,
    required this.text,
    required this.isFocused,
    this.accentColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final accent = accentColor ?? scheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isFocused ? accent : Colors.transparent,
          width: isFocused ? 2.0 : 1.0,
        ),
      ),
      child: Text(
        text,
        style: textStyle ??
            MoaiText.body(
              context,
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
