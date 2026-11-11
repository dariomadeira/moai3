import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tono de [MoaiGlassPill].
enum MoaiGlassPillTone {
  /// Vidrio claro (blanco translúcido) y texto blanco: etiquetas destacadas.
  light,

  /// Vidrio oscuro esmerilado, más chico, con el texto en un celeste sacado
  /// del acento: etiquetas delicadas sobre fotos (los géneros).
  dark,
}

/// Pastilla de vidrio para poner sobre imágenes (REDISEÑO, referencia estilo
/// visionOS): una etiqueta (un género, un estado…) con ícono opcional.
class MoaiGlassPill extends StatelessWidget {
  const MoaiGlassPill({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.tone = MoaiGlassPillTone.light,
  });

  final String label;
  final IconData? icon;

  /// Color del ícono; sin él, el del texto.
  final Color? iconColor;
  final MoaiGlassPillTone tone;

  @override
  Widget build(BuildContext context) {
    final dark = tone == MoaiGlassPillTone.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final fg = dark ? Color.lerp(primary, Colors.white, 0.78)! : Colors.white;
    final style =
        MoaiText.body(
          context,
          fontSize: dark ? 10.5 : 12,
          fontWeight: FontWeight.w500,
          height: 1,
          color: fg,
        ).copyWith(
          leadingDistribution: TextLeadingDistribution.even,
          letterSpacing: dark ? 0.3 : null,
        );
    // El texto mide con decimales: redondeado hacia arriba, cada pastilla
    // tiene un ancho entero y en una fila todas caen en píxeles enteros. Con
    // decimales el borde y la letra se acomodaban distinto en cada una y la
    // separación parecía despareja.
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final textWidth = painter.width.ceilToDouble();
    painter.dispose();
    return Container(
      padding: dark
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // Oscuro: negro azulado al 40 % con un filo apenas claro.
        color: dark ? const Color(0x66101216) : const Color(0x29FFFFFF),
        borderRadius: BorderRadius.circular(999),
        // 1 px justo (uno de 0,8 se veía distinto según dónde caía).
        border: Border.all(
          color: dark ? const Color(0x1AFFFFFF) : const Color(0x40FFFFFF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MoaiIconSizes.xs, color: iconColor ?? fg),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: textWidth,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
