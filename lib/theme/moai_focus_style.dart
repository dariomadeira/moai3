import 'package:flutter/material.dart';

/// Cómo se ve lo que tiene el foco del control (REDISEÑO): el acento sólido,
/// un poco más claro arriba, con un halo suave; el contenido va en
/// [ColorScheme.onPrimary]. Lo usan el rail y los botones de pastilla, así el
/// foco se ve igual en toda la app.
abstract final class MoaiFocusStyle {
  /// Fondo del elemento con foco. Con [borderRadius] es una pastilla o un
  /// rectángulo redondeado; sin él, un círculo. [color] reemplaza al acento
  /// (p. ej. Descuentos en el rail, con el color de su tarjeta del Inicio).
  static BoxDecoration decoration(
    ColorScheme scheme, {
    BorderRadius? borderRadius,
    Color? color,
  }) {
    final base = color ?? scheme.primary;
    return BoxDecoration(
      shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(base, Colors.white, 0.22)!, base],
      ),
      boxShadow: [
        BoxShadow(color: base.withValues(alpha: 0.45), blurRadius: 16),
      ],
    );
  }
}
