import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Ícono de Hugeicons que no está en `hugeicons_plus` (ver
/// [MoaiIcons.seriesSvg]): el SVG en [svg], del tamaño y color que se
/// pidan, como un [Icon].
class MoaiSvgIcon extends StatelessWidget {
  const MoaiSvgIcon(this.svg, {super.key, required this.size, this.color});

  final String svg;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? IconTheme.of(context).color;
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
