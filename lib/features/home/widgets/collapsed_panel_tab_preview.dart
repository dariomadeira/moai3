import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';

/// Tab vertical del acordeón (título rotado + icono).
class CollapsedPanelTabPreview extends StatelessWidget {
  final String title;
  final IconData icon;

  /// Ícono en SVG ([MoaiSvgIcon]); gana a [icon].
  final String? svgIcon;
  final bool hasFocus;

  const CollapsedPanelTabPreview({
    super.key,
    required this.title,
    required this.icon,
    this.svgIcon,
    this.hasFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // REDISEÑO: título vertical de la pestaña en la tinta suave, como la
    // fecha y el subtítulo del Inicio (con foco, el acento).
    final palette = MoaiPalette.of(context);
    final textColor = hasFocus ? scheme.primary : palette.inkSoft;
    // REDISEÑO: el ícono, del gris de los logos (antes muy claro).
    final iconColor = hasFocus ? scheme.primary : palette.inkMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: MoaiText.display(
                context,
                color: textColor,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (svgIcon case final svg?)
            MoaiSvgIcon(svg, size: MoaiIconSizes.md, color: iconColor)
          else
            Icon(icon, size: MoaiIconSizes.md, color: iconColor),
        ],
      ),
    );
  }
}
