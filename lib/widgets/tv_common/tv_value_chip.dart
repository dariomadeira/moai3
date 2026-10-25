import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';

/// Pastilla de valor para filas de ajustes (apodo, código de usuario).
class TvValueChip extends StatelessWidget {
  final String text;
  final bool isFocused;

  const TvValueChip({super.key, required this.text, required this.isFocused});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    // Sobre el fondo ambiente: píldora de cristal como el riel del selector;
    // con la ficha enfocada, el borde toma el acento.
    if (MoaiGlassScope.enabledOf(context)) {
      final dark = scheme.brightness == Brightness.dark;
      final line = dark ? Colors.white : scheme.onSurface;
      final focused = TvTile.isFocusedOf(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: line.withValues(alpha: dark ? 0.06 : 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: focused ? scheme.primary : line.withValues(alpha: 0.14),
          ),
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
