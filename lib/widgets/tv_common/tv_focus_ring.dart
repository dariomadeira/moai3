import 'package:flutter/material.dart';

/// Foco de TV como en Ajustes: el relleno de la pieza no cambia; encima va
/// un borde de 2 px del [color] y una sombrita corta del mismo color. La
/// sombra va sólo por fuera (BlurStyle.outer) para no teñir el cristal.
///
/// Lo usan las fichas de Grupos, Categorías y Canales y el buscador.
class TvFocusRing extends StatelessWidget {
  const TvFocusRing({
    super.key,
    required this.focused,
    required this.color,
    required this.child,
    this.radius = 10,
    this.circle = false,
  });

  final bool focused;
  final Color color;
  final Widget child;

  /// Radio de las esquinas (sin [circle]).
  final double radius;

  /// Pieza redonda (p. ej. el botón de borrar).
  final bool circle;

  @override
  Widget build(BuildContext context) {
    if (!focused) return child;
    final shape = circle ? BoxShape.circle : BoxShape.rectangle;
    final borderRadius = circle ? null : BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 5,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        border: Border.all(color: color, width: 2),
      ),
      child: child,
    );
  }
}
