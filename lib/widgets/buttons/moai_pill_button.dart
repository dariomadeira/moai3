import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_focus_style.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Variante de [MoaiPillButton].
enum MoaiPillButtonKind {
  /// Blanco relleno, texto oscuro: la acción principal ("Reproducir").
  filled,

  /// Vidrio esmerilado (sin borde) y texto blanco: acciones secundarias.
  glass,

  /// Círculo de vidrio esmerilado sólo con ícono ("más", flechas).
  round,
}

/// Botón de pastilla para usar sobre imágenes (REDISEÑO, referencia estilo
/// visionOS). Como las tarjetas de la grilla, no toma foco ni maneja teclas:
/// quien lo contiene decide cuál está elegido ([selected]) y lo dibuja con el
/// foco de toda la app ([MoaiFocusStyle], como el rail). Así varios botones
/// comparten un solo foco.
class MoaiPillButton extends StatelessWidget {
  const MoaiPillButton({
    super.key,
    required this.kind,
    this.icon,
    this.label,
    this.selected = false,
    this.size = height,
    this.onTap,
    this.loading = false,
  }) : assert(icon != null || label != null);

  final MoaiPillButtonKind kind;
  final IconData? icon;
  final String? label;
  final bool selected;

  /// Alto (y, en [MoaiPillButtonKind.round], diámetro).
  final double size;
  final VoidCallback? onTap;

  /// En lugar del ícono, una ruedita (p. ej. "Cargando..." al pedir el
  /// video).
  final bool loading;

  static const double height = 40;

  /// Vidrio esmerilado sobre la foto: blanco opaco a medias, sin borde.
  static const Color _glass = Color(0x40FFFFFF);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final round = kind == MoaiPillButtonKind.round;
    final white = kind == MoaiPillButtonKind.filled && !selected;
    final fg = selected
        ? scheme.onPrimary
        : white
        ? const Color(0xFF0F1218)
        : Colors.white;
    final iconSize = size < height ? MoaiIconSizes.xs + 2 : MoaiIconSizes.sm;
    final radius = round ? null : BorderRadius.circular(size / 2);

    final content = round
        ? Icon(icon, size: iconSize, color: fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                SizedBox.square(
                  dimension: iconSize - 2,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
                if (label != null) const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: iconSize, color: fg),
                if (label != null) const SizedBox(width: 8),
              ],
              if (label != null)
                Text(
                  label!,
                  maxLines: 1,
                  // Caja de línea del tamaño de la letra, con el aire
                  // repartido parejo: queda centrado en alto (con las
                  // métricas propias de la fuente, quedaba más arriba).
                  style: MoaiText.body(
                    context,
                    // Proporcional al alto: 12 en 32, 15 en 40.
                    fontSize: (size * 0.375).roundToDouble(),
                    height: 1,
                    color: fg,
                  ).copyWith(leadingDistribution: TextLeadingDistribution.even),
                ),
            ],
          );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: size,
        width: round ? size : null,
        // Mismo aire a los dos lados. El ícono trae ~2 px de margen propio
        // dentro de su caja: se descuenta a la izquierda para que a la vista
        // quede igual que a la derecha del texto.
        padding: round
            ? EdgeInsets.zero
            : EdgeInsets.only(
                left: size * 0.4 - (icon != null ? 2 : 0),
                right: size * 0.4,
              ),
        alignment: Alignment.center,
        decoration: selected
            ? MoaiFocusStyle.decoration(scheme, borderRadius: radius)
            // Sin foco, también un degradado (de un solo tono) y no un color:
            // la animación mezcla degradado con degradado. Entre un color y un
            // degradado Flutter no sabe mezclar y el botón parpadeaba
            // (azul tenue → blanco → azul).
            : BoxDecoration(
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: white
                      ? const [Colors.white, Colors.white]
                      : const [_glass, _glass],
                ),
              ),
        child: content,
      ),
    );
  }
}
