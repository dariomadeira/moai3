import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Un ícono en el acento dentro de una etiqueta de cristal cuadrada (el
/// costado de los datos de los diálogos y de las fichas de calibración).
class MoaiGlassIconTag extends StatelessWidget {
  const MoaiGlassIconTag({super.key, required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      width: size,
      height: size,
      decoration: moaiGlassTagDecoration(scheme, radius: 12),
      child: Icon(icon, size: MoaiIconSizes.md, color: scheme.primary),
    );
  }
}

/// Un dato de un diálogo (un evento de la Agenda, un descuento): ícono en
/// una [MoaiGlassIconTag], el nombre en gris y el valor en negro.
class TvInfoRow extends StatelessWidget {
  const TvInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Row(
      children: [
        MoaiGlassIconTag(icon: icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
