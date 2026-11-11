import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';

/// REDISEÑO: piezas comunes de las tarjetas del Inicio.

/// El resumen de la izquierda de las tarjetas: una etiqueta chica arriba
/// ("Películas", "Semana"…), el ícono de la tarjeta en su color con el
/// título en grande y una línea de estado abajo. Va en un ancho de [width].
class HomeCardSummary extends StatelessWidget {
  const HomeCardSummary({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    this.highlightLine = false,
    this.svgIcon,
  });

  /// Ícono SVG en lugar de [icon] (p. ej. Series, que no está en la fuente).
  final String? svgIcon;

  /// Ancho del resumen en todas las tarjetas: así los títulos y las
  /// divisiones quedan alineados de una tarjeta a otra.
  static const double width = 214;

  final String label;
  final IconData icon;

  /// El color de la tarjeta (su ícono).
  final Color color;
  final String title;
  final String line;

  /// La línea va en el acento (p. ej. un aviso o "Presioná OK").
  final bool highlightLine;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: muted,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        Row(
          children: [
            if (svgIcon case final svg?)
              MoaiSvgIcon(svg, size: MoaiIconSizes.xl, color: color)
            else
              Icon(icon, size: MoaiIconSizes.xl, color: color),
            const SizedBox(width: 10),
            // Si no entra (otro idioma, "Seguir viendo"), se achica en vez
            // de cortarse.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: highlightLine ? scheme.primary : muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// La línea vertical que separa el resumen del contenido de la tarjeta.
class HomeCardDivider extends StatelessWidget {
  const HomeCardDivider({
    super.key,
    this.height = 72,
    this.margin = const EdgeInsets.only(right: 16),
  });

  /// Sin alto (null), todo el de la tarjeta (las grandes).
  final double? height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: margin,
      color: context.scheme.onSurface.withValues(alpha: 0.08),
    );
  }
}

/// Botón de cristal de las tarjetas (no toma el foco: lo elige la tarjeta).
/// Con foco, el acento; si no, vidrio blanco con el ícono gris. [large] es
/// el de los avisos sin contenido ("Configurar", "Suscribirme"). Sin
/// [label] es sólo el ícono (las flechas de la Agenda); con [isLoading], una
/// ruedita en lugar del ícono.
class HomeGlassButton extends StatelessWidget {
  const HomeGlassButton({
    super.key,
    required this.icon,
    this.label,
    this.focused = false,
    this.large = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String? label;
  final bool focused;
  final bool large;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final iconSize = large ? MoaiIconSizes.md : MoaiIconSizes.sm;
    final iconColor = focused ? scheme.onPrimary : scheme.onSurfaceVariant;
    final text = label;
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 10)
          : EdgeInsets.symmetric(
              horizontal: text == null ? 7 : 12,
              vertical: 5,
            ),
      decoration: large
          ? moaiGlassButtonDecoration(scheme, focused: focused)
          : moaiGlassButtonDecoration(scheme, focused: focused, radius: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            SizedBox.square(
              dimension: iconSize,
              child: Padding(
                padding: const EdgeInsets.all(1.5),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              ),
            )
          else
            Icon(icon, size: iconSize, color: iconColor),
          if (text != null) ...[
            SizedBox(width: large ? 8 : 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  color: focused ? scheme.onPrimary : scheme.onSurface,
                  fontSize: large ? 14 : 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
