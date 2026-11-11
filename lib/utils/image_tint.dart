import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Ancho al que se decodifica una foto para sacarle el color: unos cientos
/// de píxeles alcanzan y es instantáneo.
const int kTintSampleWidth = 24;

/// Color predominante de unos píxeles RGBA, oscurecido para que el texto
/// blanco se lea encima (fondo del banner de Películas).
///
/// Pesa más lo vivo (saturado y no muy oscuro) que lo gris: en un afiche el
/// color que se recuerda es el de la ropa o el cielo, no el del asfalto. Si
/// la foto es toda gris, queda su gris promedio.
Color tintFromRgba(Uint8List rgba, {double maxLightness = 0.2}) {
  var r = 0.0, g = 0.0, b = 0.0, total = 0.0;
  var plainR = 0.0, plainG = 0.0, plainB = 0.0, count = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    final color = Color.fromARGB(255, rgba[i], rgba[i + 1], rgba[i + 2]);
    final hsv = HSVColor.fromColor(color);
    final weight = hsv.saturation * hsv.saturation * hsv.value;
    r += rgba[i] * weight;
    g += rgba[i + 1] * weight;
    b += rgba[i + 2] * weight;
    total += weight;
    plainR += rgba[i];
    plainG += rgba[i + 1];
    plainB += rgba[i + 2];
    count++;
  }
  if (count == 0) return const Color(0xFF000000);
  final vivid = total > count * 0.02;
  final base = vivid
      ? Color.fromARGB(255, r ~/ total, g ~/ total, b ~/ total)
      : Color.fromARGB(255, plainR ~/ count, plainG ~/ count, plainB ~/ count);
  final hsl = HSLColor.fromColor(base);
  return hsl
      .withLightness(hsl.lightness.clamp(0.0, maxLightness))
      .withSaturation(hsl.saturation.clamp(0.0, 0.7))
      .toColor();
}

/// Filo de una tarjeta con fondo [tint]: el mismo color, más claro.
Color tintBorder(Color tint) {
  final hsl = HSLColor.fromColor(tint);
  return hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 0.45)).toColor();
}

/// Decodifica [image] chiquita y devuelve su [tintFromRgba]; `null` si no
/// se pudo cargar.
Future<Color?> imageTint(ImageProvider image) async {
  final provider = ResizeImage(
    image,
    width: kTintSampleWidth,
    policy: ResizeImagePolicy.fit,
  );
  final completer = Completer<ui.Image?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      completer.complete(info.image.clone());
      info.dispose();
    },
    onError: (_, _) {
      stream.removeListener(listener);
      completer.complete(null);
    },
  );
  stream.addListener(listener);
  final decoded = await completer.future;
  if (decoded == null) return null;
  try {
    final bytes = await decoded.toByteData();
    if (bytes == null) return null;
    return tintFromRgba(bytes.buffer.asUint8List());
  } finally {
    decoded.dispose();
  }
}
