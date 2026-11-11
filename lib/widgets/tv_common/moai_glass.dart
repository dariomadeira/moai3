import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:moai3/widgets/tv_common/moai_frosted_glass.dart';

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
    this.frosted = false,
  });

  /// Radio de las esquinas de los paneles grandes (el del acordeón); lo
  /// que quiera verse "del mismo juego" que el panel usa este.
  static const double panelRadius = 16;

  /// Sombra de los paneles grandes: los despega del fondo. La usan también
  /// las tarjetas que van "del mismo juego" (la destacada de películas).
  /// El color, el del modo ([MoaiPalette.panelShadow]).
  static List<BoxShadow> panelShadowOf(BuildContext context) => [
    BoxShadow(
      color: MoaiPalette.of(context).panelShadow,
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  /// REDISEÑO: panel general de vidrio esmerilado (el fondo desenfocado se
  /// ve a través). Sólo los paneles grandes de cada pantalla; las tarjetas y
  /// piezas de adentro van sin esto (vidrio claro encima del panel).
  final bool frosted;

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

  /// Piezas sobre el panel esmerilado (referencia estilo visionOS): vidrio
  /// más claro que el panel, con filo de luz con degradado (fuerte arriba a
  /// la izquierda, casi nada abajo a la derecha), como si la luz viniera de
  /// arriba. Mismo material con y sin foco; el foco cambia el filo por el
  /// borde del acento. Los colores, los del modo ([MoaiPalette]: `glassCard`,
  /// `glassChip`, `specularRim`).
  Decoration _rimFor(ColorScheme scheme, MoaiPalette palette) {
    if (!focused) {
      return _GlassRim(
        radius: borderRadius,
        rim: palette.specularRim,
        rimWidth: 1.2,
        sheen: Colors.transparent, // sin brillo: sólo el borde
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: scheme.primary, width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    if (tint != null) return _tinted(context, tint);
    if (frosted) return _frosted(context);
    return _clear(context);
  }

  /// Panel grande: vidrio esmerilado estilo visionOS (referencia del usuario
  /// `4574037118559472.jpg`). El fondo desenfocado se ve a través
  /// ([MoaiFrostedBackdrop]), un velo blanco suave un poco más claro arriba,
  /// borde de luz y sombra que lo despega del fondo.
  Widget _frosted(BuildContext context) {
    final palette = MoaiPalette.of(context);
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: panelShadowOf(context),
      ),
      foregroundDecoration: MoaiFrostedRim(
        radius: borderRadius,
        colors: palette.frostedRim,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const Positioned.fill(child: MoaiFrostedBackdrop()),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // 2026-11-03: un pelín más blanco (era 30 % → 15 %).
                    colors: palette.frostedVeil,
                  ),
                ),
              ),
            ),
            Container(padding: padding, alignment: alignment, child: child),
          ],
        ),
      ),
    );
  }

  Widget _clear(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = MoaiPalette.of(context);
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: solid ? palette.glassCard : palette.glassChip,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: palette.glassShadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      // Borde por encima: con foco crece sin mover el contenido.
      foregroundDecoration: _rimFor(scheme, palette),
      padding: padding,
      alignment: alignment,
      child: child,
    );
  }

  /// Una pieza teñida (p. ej. `scheme.primary` para una activa): degradado
  /// del tinte, brillo arriba y borde especular del mismo color.
  Widget _tinted(BuildContext context, Color tint) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);

    var fill = dark
        ? [tint.withValues(alpha: 0.30), tint.withValues(alpha: 0.14)]
        : [tint.withValues(alpha: 0.22), tint.withValues(alpha: 0.10)];

    if (focused) {
      final wash = scheme.primary.withValues(alpha: dark ? 0.10 : 0.08);
      fill = [for (final c in fill) Color.alphaBlend(wash, c)];
    }

    final rim = focused
        ? List.filled(3, scheme.primary)
        : dark
        ? [
            tint.withValues(alpha: 0.55),
            tint.withValues(alpha: 0.04),
            tint.withValues(alpha: solid ? 0.05 : 0.12),
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

/// Cristal oscuro para lo que va sobre video: el claro se lava. Sin desenfoque,
/// para no cargar cada cuadro.
BoxDecoration moaiVideoGlassDecoration({double radius = 14}) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x99262A31), Color(0x8C12141A)],
  ),
  border: Border.all(color: const Color(0x2EFFFFFF)),
);

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

/// Botón chico de cristal (acciones de un encabezado): en reposo, el mismo
/// vidrio blanco con filo de luz que las piezas de [MoaiGlass] (p. ej. los
/// días de Descuentos); con foco, [accent] pleno con brillo y halo, como
/// [TvIconActionButton]. [highlighted] marca un estado activo sin foco
/// (p. ej. el canal ya es favorito).
BoxDecoration moaiGlassButtonDecoration(
  ColorScheme scheme, {
  required bool focused,
  bool highlighted = false,
  Color? accent,
  double radius = 999,
}) {
  // Los tres estados tienen la misma forma (degradado, borde de 1 y un
  // halo de 12): así, al animar el cambio de foco, el color pasa parejo de
  // uno a otro. Antes sin foco era un relleno plano y con foco un degradado;
  // a mitad de la animación se desvanecía uno antes de aparecer el otro y el
  // botón titilaba.
  final Color top;
  final Color bottom;
  final Color rim;
  final Color glow;
  if (focused) {
    final color = accent ?? scheme.primary;
    top = Color.lerp(color, Colors.white, 0.18)!;
    bottom = color;
    // Borde invisible del mismo ancho que el de sin foco: el borde suma al
    // tamaño del botón y, si no, al enfocarlo se achica y mueve lo de al lado.
    rim = color.withValues(alpha: 0);
    glow = color.withValues(alpha: 0.4);
  } else if (highlighted) {
    final chip = moaiGlassChipDecoration(
      scheme,
      radius: radius,
      highlighted: true,
    );
    top = bottom = chip.color!;
    rim = (chip.border! as Border).top.color;
    glow = scheme.primary.withValues(alpha: 0);
  } else {
    // REDISEÑO (2026-11-01): antes una [moaiGlassChipDecoration] gris.
    final palette = MoaiPalette.ofScheme(scheme);
    top = bottom = palette.glassCard;
    rim = palette.glassRim;
    glow = (accent ?? scheme.primary).withValues(alpha: 0);
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    ),
    border: Border.all(color: rim),
    boxShadow: [BoxShadow(color: glow, blurRadius: 12)],
  );
}

/// Etiqueta de cristal (un estado o un dato, no una acción: "1400 canales",
/// "Instalado"): más blanca que la ficha sobre la que va, con filo de luz.
/// El texto va en gris ([ColorScheme.onSurfaceVariant]) o, con [tint], en
/// [moaiGlassTagForeground].
///
/// [tint] da color a la etiqueta (p. ej. verde para "Instalado"): el blanco
/// se tiñe apenas y el filo toma el color.
BoxDecoration moaiGlassTagDecoration(
  ColorScheme scheme, {
  double radius = 20,
  Color? tint,
}) {
  final palette = MoaiPalette.ofScheme(scheme);
  final base = palette.tagFill;
  if (tint != null) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      // Al 24 %: se acerca al filo (al 38 %) sin taparlo.
      color: Color.alphaBlend(tint.withValues(alpha: 0.24), base),
      border: Border.all(color: tint.withValues(alpha: 0.38)),
    );
  }
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    color: base,
    border: Border.all(color: palette.tagRim),
  );
}

/// Texto e ícono de una etiqueta de cristal: con [tint], ese color un poco
/// más oscuro (se lee sobre el blanco); sin él, gris.
Color moaiGlassTagForeground(ColorScheme scheme, {Color? tint}) {
  if (tint == null) return scheme.onSurfaceVariant;
  if (scheme.brightness == Brightness.dark) {
    return Color.lerp(tint, Colors.white, 0.35)!;
  }
  return Color.lerp(tint, Colors.black, 0.22)!;
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
