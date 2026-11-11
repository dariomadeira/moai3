import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';

/// Pill de metadatos utilizado para información contextual en TV
/// (ej. visor de canal, conteos de cabecera en paneles).
class TvMetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;

  /// Ícono SVG (ver [MoaiSvgIcon]) en lugar de [icon], para los de Hugeicons
  /// que no están en `hugeicons_plus`.
  final String? svgIcon;
  final Color? color;
  final Color? foreground;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry padding;

  /// Color de la etiqueta de cristal (ver [moaiGlassTagDecoration]); sin él,
  /// blanca con texto gris.
  final Color? tint;

  /// En cristal, el color del ícono y el texto sobre la etiqueta blanca (p. ej.
  /// el puntaje, que se colorea según la nota); sin él, el de [tint].
  final Color? glassForeground;

  /// Los contadores de las cabeceras ("501 Canales", extensiones, juegos
  /// instalados): gris pizarra medio, sólido con el texto blanco. Se lee
  /// igual sobre el cristal claro y sobre el ahumado del modo oscuro (antes
  /// un naranja fijo).
  static const Color countTint = Color(0xFF64748B);

  const TvMetaPill({
    super.key,
    required this.label,
    this.icon,
    this.svgIcon,
    this.color,
    this.foreground,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.tint,
    this.glassForeground,
    this.dense = false,
  });

  /// Un poco más chica (las de la ficha de películas y series): menos alto,
  /// ícono y letra apenas menores. Usa su propio relleno, no [padding].
  final bool dense;

  static const EdgeInsets _densePadding = EdgeInsets.symmetric(
    horizontal: 9,
    vertical: 6,
  );

  EdgeInsetsGeometry get _padding => dense ? _densePadding : padding;

  double get _iconSize => dense ? 18 : MoaiIconSizes.md;

  double get _fontSize => dense ? 11.5 : 12;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // La píldora neutra (sin color o con el violeta por defecto) es de
    // cristal tenue; los colores con significado (calidad, puntaje) se
    // respetan.
    final neutral =
        color == null ||
        color == scheme.tertiaryContainer ||
        glassForeground != null;
    if (neutral) return _buildGlass(context, scheme);
    final bg = color ?? scheme.tertiaryContainer;
    final fg = foreground ?? scheme.onTertiaryContainer;

    final effectiveTextStyle =
        textStyle ??
        MoaiText.body(
          context,
          color: fg,
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon(fg) case final icon?) ...[icon, const SizedBox(width: 6)],
          _label(effectiveTextStyle),
        ],
      ),
    );
  }

  Widget? _icon(Color color) => svgIcon != null
      ? MoaiSvgIcon(svgIcon!, size: _iconSize, color: color)
      : icon != null
      ? Icon(icon, size: _iconSize, color: color)
      : null;

  /// El texto, bajado lo justo para verse centrado en la píldora y con el
  /// ícono ([MoaiText.opticalCenterShift]). Sólo al pintar: no cambia el alto.
  Widget _label(TextStyle style) => Transform.translate(
    offset: Offset(0, MoaiText.opticalCenterShift(style.fontSize ?? 12)),
    child: Text(label, style: style),
  );

  Widget _buildGlass(BuildContext context, ColorScheme scheme) {
    // Con [tint]: la pastilla de los géneros de película (`TvMovieGenreChip`),
    // redonda, del color sólido y con texto e ícono blancos. Sin él,
    // etiqueta de cristal blanca con el texto en gris.
    final tint = this.tint;
    final solid = tint != null && glassForeground == null;
    final fg = solid
        ? Colors.white
        : glassForeground ?? moaiGlassTagForeground(scheme, tint: tint);
    return Container(
      padding: _padding,
      decoration: solid
          ? ShapeDecoration(color: tint, shape: const StadiumBorder())
          : moaiGlassTagDecoration(scheme, tint: tint),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_icon(fg) case final icon?) ...[icon, const SizedBox(width: 6)],
          _label(
            textStyle?.copyWith(color: fg) ??
                MoaiText.body(
                  context,
                  color: fg,
                  fontSize: _fontSize,
                  fontWeight: solid ? FontWeight.w600 : FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
