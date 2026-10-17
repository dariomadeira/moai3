import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: effectiveTextStyle),
        ],
      ),
    );
  }
}
