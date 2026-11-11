import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/utils/image_tint.dart';

Uint8List _pixels(List<(int, int, int)> colors) => Uint8List.fromList([
  for (final (r, g, b) in colors) ...[r, g, b, 255],
]);

void main() {
  test('gana el color vivo sobre el gris y queda oscuro', () {
    final tint = tintFromRgba(
      _pixels([
        for (var i = 0; i < 6; i++) (120, 120, 120),
        for (var i = 0; i < 2; i++) (220, 40, 30),
      ]),
    );
    final hsl = HSLColor.fromColor(tint);
    // Rojo, no gris.
    expect(hsl.hue < 15 || hsl.hue > 345, isTrue);
    expect(hsl.saturation, greaterThan(0.3));
    expect(hsl.lightness, lessThanOrEqualTo(0.2 + 1e-3));
  });

  test('una foto gris queda en su gris, oscurecido', () {
    final hsl = HSLColor.fromColor(
      tintFromRgba(_pixels([for (var i = 0; i < 8; i++) (200, 200, 200)])),
    );
    expect(hsl.saturation, lessThan(0.05));
    expect(hsl.lightness, lessThanOrEqualTo(0.2 + 1e-3));
  });

  test('sin píxeles, negro', () {
    expect(tintFromRgba(Uint8List(0)), const Color(0xFF000000));
  });
}
