import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Pill de metadatos utilizado para información contextual en TV
/// (ej. visor de canal, conteos de cabecera en paneles).
class TvMetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  const TvMetaPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.foreground,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // En cristal, la píldora neutra (sin color o con el violeta por defecto)
    // pasa a cristal tenue; los colores con significado (calidad, puntaje)
    // se respetan.
    final glass =
        MoaiGlassScope.enabledOf(context) &&
        (color == null || color == scheme.tertiaryContainer);
    if (glass) return _buildGlass(context, scheme);
    final bg = color ?? scheme.tertiaryContainer;
    final fg = foreground ?? scheme.onTertiaryContainer;

    final effectiveTextStyle = textStyle ??
        MoaiText.body(
          context,
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MoaiIconSizes.md, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: effectiveTextStyle),
        ],
      ),
    );
  }

  Widget _buildGlass(BuildContext context, ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    final line = dark ? Colors.white : scheme.onSurface;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: line.withValues(alpha: dark ? 0.06 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: MoaiIconSizes.md, color: scheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style:
                textStyle?.copyWith(color: scheme.onSurface) ??
                MoaiText.body(
                  context,
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
