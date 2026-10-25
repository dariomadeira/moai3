import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Superficie de "cristal pulido": relleno translúcido con degradado, brillo
/// en la mitad superior, borde especular (claro arriba a la izquierda, tenue
/// abajo) y sombra suave.
///
/// No usa [BackdropFilter]: sobre el fondo ambiente, que ya es difuso, el
/// desenfoque no cambia nada visible y en el Chromecast cuesta caro.
///
/// [tint] tiñe el cristal (p. ej. `scheme.primary` para una pieza activa);
/// sin tint es cristal neutro.
class MoaiGlass extends StatelessWidget {
  const MoaiGlass({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.width,
    this.height,
    this.tint,
    this.elevated = true,
    this.alignment,
    this.solid = false,
    this.focused = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? tint;
  final AlignmentGeometry? alignment;

  /// Panel grande: cristal discreto, que se funde con el fondo en vez de
  /// sobresalir (menos brillo y borde). Conviene usarlo sin [elevated].
  final bool solid;

  /// Foco de TV: borde del acento por dentro (no se corta en listas) y un
  /// tinte muy suave; el resto del cristal no cambia.
  final bool focused;

  /// Con sombra; una pieza anidada dentro de otro cristal va sin ella.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    final tint = this.tint;

    List<Color> fill;
    if (tint != null) {
      fill = dark
          ? [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.14)]
          : [tint.withValues(alpha: 0.22), tint.withValues(alpha: 0.10)];
    } else {
      fill = dark
          ? [
              Color.alphaBlend(
                Colors.white.withValues(alpha: solid ? 0.02 : 0.10),
                scheme.surface.withValues(alpha: solid ? 0.45 : 0.42),
              ),
              Color.alphaBlend(
                Colors.white.withValues(alpha: solid ? 0.0 : 0.03),
                scheme.surface.withValues(alpha: solid ? 0.38 : 0.30),
              ),
            ]
          : [
              Colors.white.withValues(alpha: solid ? 0.55 : 0.62),
              Colors.white.withValues(alpha: solid ? 0.42 : 0.34),
            ];
    }

    if (focused) {
      final wash = scheme.primary.withValues(alpha: dark ? 0.10 : 0.08);
      fill = [for (final c in fill) Color.alphaBlend(wash, c)];
    }

    final rimLight = tint ?? Colors.white;
    final rim = focused
        ? List.filled(3, scheme.primary)
        : dark
        ? [
            rimLight.withValues(
              alpha: tint != null ? 0.55 : (solid ? 0.14 : 0.32),
            ),
            rimLight.withValues(alpha: 0.04),
            rimLight.withValues(alpha: solid ? 0.05 : 0.12),
          ]
        : [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.30),
            scheme.shadow.withValues(alpha: 0.10),
          ];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fill,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: dark
                      ? Colors.black.withValues(alpha: 0.38)
                      : scheme.primary.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      foregroundDecoration: _GlassRim(
        radius: borderRadius,
        rim: rim,
        rimWidth: focused ? 2 : 1,
        sheen: Colors.white.withValues(
          alpha: dark ? (solid ? 0.025 : 0.07) : (solid ? 0.15 : 0.35),
        ),
      ),
      padding: padding,
      alignment: alignment,
      child: child,
    );
  }
}

/// Brillo superior + borde con degradado, pintados encima del contenido.
class _GlassRim extends Decoration {
  const _GlassRim({
    required this.radius,
    required this.rim,
    required this.rimWidth,
    required this.sheen,
  });

  final double radius;
  final List<Color> rim;
  final double rimWidth;
  final Color sheen;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _GlassRimPainter(this);

  // Sin igualdad cada rebuild crea un borde "distinto" y fuerza a repintar
  // la pieza aunque no haya cambiado (p. ej. todos los ítems de una lista).
  @override
  bool operator ==(Object other) =>
      other is _GlassRim &&
      other.radius == radius &&
      other.rimWidth == rimWidth &&
      other.sheen == sheen &&
      listEquals(other.rim, rim);

  @override
  int get hashCode => Object.hash(radius, rimWidth, sheen, Object.hashAll(rim));
}

class _GlassRimPainter extends BoxPainter {
  _GlassRimPainter(this.d);

  final _GlassRim d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(d.radius));

    canvas.save();
    canvas.clipRRect(rrect);
    final sheenRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      math.min(rect.height * 0.5, 72),
    );
    canvas.drawRect(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [d.sheen, d.sheen.withValues(alpha: 0)],
        ).createShader(sheenRect),
    );
    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(d.rimWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = d.rimWidth
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: d.rim,
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
  }
}

/// Marca un subárbol que está sobre el fondo ambiente: ahí los componentes
/// compartidos (p. ej. el acordeón) se dibujan de cristal. Fuera de él (diálogos,
/// pantallas que aún usan la imagen de fondo) mantienen su estilo opaco.
class MoaiGlassScope extends InheritedWidget {
  const MoaiGlassScope({super.key, required super.child});

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MoaiGlassScope>() != null;

  @override
  bool updateShouldNotify(MoaiGlassScope oldWidget) => false;
}

/// Superficie de un diálogo sobre el fondo ambiente: sólida (flota sobre la
/// pantalla oscurecida), un tono más clara arriba, borde de luz tenue y sombra
/// amplia. Sin manchas de luz: en un recuadro chico compiten con la pantalla.
BoxDecoration moaiDialogDecoration(ColorScheme scheme, {double radius = 20}) {
  final dark = scheme.brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: dark
          ? [
              Color.alphaBlend(
                Colors.white.withValues(alpha: 0.04),
                scheme.surfaceContainer,
              ),
              scheme.surfaceContainerLow,
            ]
          : [scheme.surfaceContainerLowest, scheme.surfaceContainerLow],
    ),
    border: Border.all(
      color: (dark ? Colors.white : scheme.onSurface).withValues(alpha: 0.10),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.55 : 0.18),
        blurRadius: 40,
        offset: const Offset(0, 16),
      ),
    ],
  );
}

/// "Pozo" de cristal: zona que agrupa contenido dentro de un panel o diálogo
/// (listas, estados vacíos) sin pesar.
BoxDecoration moaiGlassWellDecoration(
  ColorScheme scheme, {
  double radius = 16,
}) {
  final dark = scheme.brightness == Brightness.dark;
  final line = dark ? Colors.white : scheme.onSurface;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: line.withValues(alpha: dark ? 0.03 : 0.04),
    border: Border.all(color: line.withValues(alpha: 0.08)),
  );
}

/// Botón chico de cristal (acciones de un encabezado): en reposo es una
/// [moaiGlassChipDecoration]; con foco, [accent] pleno con brillo y halo,
/// como [TvIconActionButton]. [highlighted] marca un estado activo sin foco
/// (p. ej. el canal ya es favorito).
BoxDecoration moaiGlassButtonDecoration(
  ColorScheme scheme, {
  required bool focused,
  bool highlighted = false,
  Color? accent,
  double radius = 999,
}) {
  if (!focused) {
    return moaiGlassChipDecoration(
      scheme,
      radius: radius,
      highlighted: highlighted,
    );
  }
  final color = accent ?? scheme.primary;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(color, Colors.white, 0.18)!, color],
    ),
    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)],
  );
}

/// Píldora chica de cristal (contadores, etiquetas).
BoxDecoration moaiGlassChipDecoration(
  ColorScheme scheme, {
  double radius = 999,
  bool highlighted = false,
}) {
  final dark = scheme.brightness == Brightness.dark;
  final line = dark ? Colors.white : scheme.onSurface;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: highlighted
        ? scheme.primary.withValues(alpha: 0.18)
        : line.withValues(alpha: dark ? 0.06 : 0.08),
    border: Border.all(
      color: highlighted
          ? scheme.primary.withValues(alpha: 0.5)
          : line.withValues(alpha: 0.14),
    ),
  );
}
