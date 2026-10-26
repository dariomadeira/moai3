import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Color de cada tarjeta del Inicio: un halo tenue arriba a la izquierda
/// que las distingue sin pelear con el fondo. El del clima sale del tiempo
/// que hace.
abstract final class HomeCardColors {
  static const Color events = Color(0xFFF97316);
  static const Color continueWatching = Color(0xFF22C55E);
  static const Color watchlist = Color(0xFFA855F7);
  static const Color trailers = Color(0xFFF43F5E);
  static const Color arcade = Color(0xFF14B8A6);
  static const Color discounts = Color(0xFFEAB308);
}

/// Tarjeta del Inicio: cristal sólido con el halo de su color arriba a la
/// izquierda (como el del clima) y el contenido con [padding].
///
/// El halo es un degradado radial fijo: no le suma trabajo al TV.
class HomeCard extends StatelessWidget {
  const HomeCard({
    super.key,
    required this.glow,
    required this.padding,
    required this.child,
    this.focused = false,
    this.radius = 16,
  });

  final Color glow;
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// Borde de foco en la tarjeta entera (cuando no lo lleva una pieza de
  /// adentro).
  final bool focused;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return MoaiGlass(
      borderRadius: radius,
      elevated: false,
      solid: true,
      focused: focused,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -40,
              top: -50,
              width: 170,
              height: 170,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: dark ? 0.14 : 0.18),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
