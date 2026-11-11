import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';

/// REDISEÑO (2026-10-30): vidrio esmerilado estilo visionOS para los paneles
/// grandes, sin [BackdropFilter].
///
/// El fondo de la app es una imagen fija (`MoaiAmbientBackground`), así que
/// en vez de desenfocar en vivo (caro en el Chromecast y se recalcula con
/// cada cambio del panel) el panel dibuja una copia ya desenfocada del mismo
/// fondo (`background_blur.webp`), alineada con la pantalla: se ve el fondo
/// borroso "a través" del vidrio y no cuesta nada.
class MoaiFrostedBackdrop extends StatefulWidget {
  const MoaiFrostedBackdrop({super.key});

  /// Copia desenfocada de `assets/images/background.webp` (mitad de
  /// resolución, desenfoque gaussiano).
  // PRUEBA (2026-11-01): la de `background_color.webp` (mitad de
  // resolución, desenfoque gaussiano de radio 30). La de antes:
  // 'assets/images/background_blur.webp'.
  // PRUEBA (2026-11-02, descartada el 2026-11-03): la de
  // `background_new.webp` ('assets/images/background_new_blur.webp').
  // PRUEBA (2026-11-03): sigue al fondo elegido en
  // `trialBackground` de moai_ambient_background.dart. El aprobado:
  // 'assets/images/background_color_blur.webp'.
  static const String blurredAsset = MoaiAmbientBackground.blurredAsset;

  @override
  State<MoaiFrostedBackdrop> createState() => _MoaiFrostedBackdropState();
}

class _MoaiFrostedBackdropState extends State<MoaiFrostedBackdrop> {
  /// Cada imagen (una por modo) se decodifica una vez y la comparten todos
  /// los paneles.
  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<ui.Image>> _loading = {};

  String? _asset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _asset = MoaiAmbientBackground.blurredAssetFor(
      Theme.of(context).brightness,
    );
    if (!_images.containsKey(_asset)) _load(_asset!);
  }

  Future<void> _load(String asset) async {
    final image = await (_loading[asset] ??= _decode(asset));
    _images[asset] = image;
    if (mounted && asset == _asset) setState(() {});
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  @override
  Widget build(BuildContext context) {
    final image = _images[_asset];
    if (image == null) return const SizedBox.expand();
    return _FrostedPaint(image: image, screen: MediaQuery.sizeOf(context));
  }
}

class _FrostedPaint extends LeafRenderObjectWidget {
  const _FrostedPaint({required this.image, required this.screen});

  final ui.Image image;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFrosted(image, screen);

  @override
  void updateRenderObject(BuildContext context, _RenderFrosted renderObject) {
    renderObject
      ..image = image
      ..screen = screen;
  }
}

class _RenderFrosted extends RenderBox {
  _RenderFrosted(this._image, this._screen);

  ui.Image _image;
  set image(ui.Image value) {
    if (value == _image) return;
    _image = value;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size value) {
    if (value == _screen) return;
    _screen = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final imageSize = Size(_image.width.toDouble(), _image.height.toDouble());
    // Mismo encuadre que el fondo: `cover` sobre toda la pantalla.
    final fitted = applyBoxFit(BoxFit.cover, imageSize, _screen);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & imageSize,
    );
    final screenRect = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & _screen,
    );
    // Dónde está el panel en la pantalla: el fondo se corre al revés.
    final global = localToGlobal(Offset.zero);
    final canvas = context.canvas;
    canvas.save();
    canvas.clipRect(offset & size);
    canvas.drawImageRect(
      _image,
      source,
      screenRect.shift(offset - global),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }
}

/// Borde de luz del vidrio: brillante en el filo de arriba, casi nada en los
/// costados y una luz suave abajo (el canto del vidrio).
class MoaiFrostedRim extends Decoration {
  const MoaiFrostedRim({required this.radius, required this.colors});

  final double radius;

  /// Arriba, costados (2) y abajo: los del modo ([MoaiPalette.frostedRim]).
  final List<Color> colors;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _FrostedRimPainter(radius, colors);

  @override
  bool operator ==(Object other) =>
      other is MoaiFrostedRim &&
      other.radius == radius &&
      listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(radius, Object.hashAll(colors));
}

class _FrostedRimPainter extends BoxPainter {
  _FrostedRimPainter(this.radius, this.colors);

  final double radius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      // Concéntrico con la esquina (el trazo va 0,5 hacia adentro).
      Radius.circular(radius - 0.5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0, 0.18, 0.8, 1],
        ).createShader(rect),
    );
  }
}
