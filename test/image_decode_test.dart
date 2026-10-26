import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/utils/image_decode.dart';

void main() {
  int decodeWidth(double w, double h, {double dpr = 2}) =>
      coverDecodeWidth(width: w, height: h, devicePixelRatio: dpr);

  test('una foto de cine (2,39:1) cubre el alto del recuadro', () {
    final width = decodeWidth(192, 108);
    // Decodificada a ese ancho, su alto llega al del recuadro (216 px).
    expect(width / 2.39, greaterThanOrEqualTo(108 * 2));
  });

  test('una foto 16:9 o más angosta (3:2) cubre ancho y alto', () {
    final width = decodeWidth(192, 108);
    expect(width, greaterThanOrEqualTo(192 * 2));
    // 3:2: a ese ancho, el alto también sobra.
    expect(width / 1.5, greaterThanOrEqualTo(108 * 2));
  });

  test('un recuadro muy ancho pide su propio ancho', () {
    expect(decodeWidth(600, 100, dpr: 1), 600);
  });

  test('sigue siendo mucho menos que la foto original', () {
    // Miniatura del Inicio: unos 520 px contra los 1920–4096 del catálogo.
    expect(decodeWidth(192, 108), lessThan(600));
  });
}
