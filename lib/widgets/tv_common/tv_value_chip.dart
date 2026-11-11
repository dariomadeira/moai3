import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Pastilla de valor para filas de ajustes (apodo, código de usuario).
class TvValueChip extends StatelessWidget {
  final String text;
  final bool isFocused;

  const TvValueChip({super.key, required this.text, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    // Sobre el fondo ambiente: píldora de cristal como el riel del selector
    // (en claro, el mismo vidrio blanco con filo de luz). No cambia con el
    // foco: el borde de acento es de la ficha, no de la pastilla.
    if (MoaiGlassScope.enabledOf(context)) {
      final dark = scheme.brightness == Brightness.dark;
      final line = dark ? Colors.white : scheme.onSurface;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: dark
              ? line.withValues(alpha: 0.06)
              : const Color(0x99FFFFFF), // blanco al 60 %
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dark
                ? line.withValues(alpha: 0.14)
                : const Color(0xB3FFFFFF), // filo de luz al 70 %
          ),
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x14000000), // negro al 8 %: lo despega
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          text,
          style: MoaiText.body(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: scheme.onSurface,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isFocused ? scheme.onPrimary : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: MoaiText.body(
          context,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isFocused ? scheme.primary : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
