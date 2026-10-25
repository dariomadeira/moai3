import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Fondo de luz ambiente: tres manchas de color del [ColorScheme] sobre la
/// superficie, más viñeta y grano (el grano evita las bandas de los
/// degradados en teles de 8 bits). Sin imágenes.
///
/// Es estático: sólo se repinta cuando cambia el esquema (acento o tema), con
/// una transición de 800 ms. Una deriva continua costaba casi un núcleo de
/// CPU redibujando toda la pantalla y no se llegaba a notar.
class MoaiAmbientBackground extends StatefulWidget {
  const MoaiAmbientBackground({super.key});

  @override
  State<MoaiAmbientBackground> createState() => _MoaiAmbientBackgroundState();
}

class _MoaiAmbientBackgroundState extends State<MoaiAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    value: 1,
  );
  _AmbientPalette? _from;
  _AmbientPalette? _to;
  ui.Image? _grain;

  @override
  void initState() {
    super.initState();
    _buildGrain();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _AmbientPalette.of(Theme.of(context).colorScheme);
    if (_to == null) {
      _from = _to = next;
    } else if (next != _to) {
      _from = _AmbientPalette.lerp(_from!, _to!, _blend.value);
      _to = next;
      if (MediaQuery.disableAnimationsOf(context)) {
        _blend.value = 1;
      } else {
        _blend.forward(from: 0);
      }
    }
  }

  Future<void> _buildGrain() async {
    const size = 128;
    final rnd = math.Random(42);
    final pixels = Uint8List(size * size * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      final v = rnd.nextInt(256);
      pixels[i] = v;
      pixels[i + 1] = v;
      pixels[i + 2] = v;
      pixels[i + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() => _grain = image);
  }

  @override
  void dispose() {
    _blend.dispose();
    _grain?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        // Quieto y caro de pintar: candidato a quedar en la caché de raster.
        isComplex: true,
        painter: _AmbientPainter(
          blend: _blend,
          from: _from!,
          to: _to!,
          grain: _grain,
        ),
      ),
    );
  }
}

/// Una mancha: centro (0–1) y radio relativo al ancho. Son las posiciones
/// que tenía la deriva en el cuadro inicial, así el fondo se ve igual.
class _Blob {
  const _Blob(this.x, this.y, this.r);

  final double x, y, r;
}

const _blobs = [
  _Blob(0.1976, 0.1847, 0.78), // principal
  _Blob(0.9050, 0.8661, 0.62), // contraste
  _Blob(0.6008, 0.3304, 0.40), // acompañante
];

/// Caída aproximadamente gaussiana para que no se vea el borde del círculo.
const _falloffStops = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
const _falloff = [1.0, 0.86, 0.6, 0.32, 0.11, 0.0];

/// Colores del fondo ya resueltos desde el esquema (con su alpha).
@immutable
class _AmbientPalette {
  const _AmbientPalette(this.base, this.blobs, this.vignette);

  factory _AmbientPalette.of(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    return dark
        ? _AmbientPalette(s.surface, [
            s.primary.withValues(alpha: 0.30),
            s.tertiary.withValues(alpha: 0.22),
            s.secondary.withValues(alpha: 0.15),
          ], Colors.black.withValues(alpha: 0.5))
        : _AmbientPalette(s.surface, [
            s.primaryContainer.withValues(alpha: 0.60),
            s.tertiaryContainer.withValues(alpha: 0.50),
            s.secondaryContainer.withValues(alpha: 0.35),
          ], s.primary.withValues(alpha: 0.10));
  }

  static _AmbientPalette lerp(_AmbientPalette a, _AmbientPalette b, double t) {
    return _AmbientPalette(Color.lerp(a.base, b.base, t)!, [
      for (var i = 0; i < a.blobs.length; i++)
        Color.lerp(a.blobs[i], b.blobs[i], t)!,
    ], Color.lerp(a.vignette, b.vignette, t)!);
  }

  final Color base;
  final List<Color> blobs;
  final Color vignette;

  @override
  bool operator ==(Object other) =>
      other is _AmbientPalette &&
      other.base == base &&
      other.vignette == vignette &&
      _listEquals(other.blobs, blobs);

  @override
  int get hashCode => Object.hash(base, vignette, Object.hashAll(blobs));

  static bool _listEquals(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.blend,
    required this.from,
    required this.to,
    required this.grain,
  }) : super(repaint: blend);

  final Animation<double> blend;
  final _AmbientPalette from;
  final _AmbientPalette to;
  final ui.Image? grain;

  static const _grainOpacity = 0.09;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final p = _AmbientPalette.lerp(
      from,
      to,
      Curves.easeOutCubic.transform(blend.value),
    );

    canvas.drawRect(rect, Paint()..color = p.base);

    for (var i = 0; i < _blobs.length; i++) {
      final b = _blobs[i];
      final center = Offset(b.x * size.width, b.y * size.height);
      final color = p.blobs[i];
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(center, b.r * size.width, [
            for (final f in _falloff) color.withValues(alpha: color.a * f),
          ], _falloffStops),
      );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 0.85,
          colors: [p.vignette.withValues(alpha: 0), p.vignette],
          stops: const [0.55, 1],
        ).createShader(rect),
    );

    final g = grain;
    if (g != null) {
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.overlay
          ..color = Colors.black.withValues(alpha: _grainOpacity)
          ..shader = ImageShader(
            g,
            TileMode.repeated,
            TileMode.repeated,
            Matrix4.identity().storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) =>
      old.from != from || old.to != to || old.grain != grain;
}
