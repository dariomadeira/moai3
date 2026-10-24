import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Imágenes de fondo de la app, con su tamaño en píxeles del archivo.
enum MoaiBackground {
  screen('assets/images/fondo.png', 3840, 2160),
  dialog('assets/images/dialog.png', 2100, 2160),
  movie('assets/images/movie.png', 3840, 2160);

  const MoaiBackground(this.asset, this.width, this.height);

  final String asset;
  final int width;
  final int height;
}

/// Fondo que cubre su espacio ([BoxFit.cover]) y se decodifica al tamaño en
/// pantalla, no al del archivo: en una tele 1080p el fondo 4K ocupa ~8 MB en
/// vez de ~33 MB. Los archivos se mantienen grandes por si un aparato dibuja
/// la interfaz en 4K.
class MoaiBackgroundImage extends StatelessWidget {
  const MoaiBackgroundImage(this.background, {super.key});

  final MoaiBackground background;

  /// Ancho a decodificar para cubrir [box] (en píxeles lógicos).
  ///
  /// Redondea hacia arriba en escalones de 128 px para que un diálogo que
  /// cambia un poco de alto reutilice la misma imagen ya decodificada, y
  /// nunca supera el ancho del archivo.
  static int decodeWidth(
    MoaiBackground background,
    Size box,
    double devicePixelRatio,
  ) {
    final aspect = background.width / background.height;
    final needed = math.max(box.width, box.height * aspect) * devicePixelRatio;
    final stepped = (needed / 128).ceil() * 128;
    return stepped.clamp(1, background.width);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screen = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : screen.width,
          constraints.hasBoundedHeight ? constraints.maxHeight : screen.height,
        );
        return Image.asset(
          background.asset,
          fit: BoxFit.cover,
          cacheWidth: decodeWidth(background, box, dpr),
          gaplessPlayback: true,
        );
      },
    );
  }
}
