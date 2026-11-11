import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';

void main() {
  tearDown(() => HomeClock.setAccent(const Color(0xFF2B4CFF)));

  test('con otro acento el degradado es otra función (los títulos se '
      'repintan)', () {
    HomeClock.setAccent(const Color(0xFF2B4CFF));
    final blue = HomeClock.timeShader;

    HomeClock.setAccent(const Color(0xFFE53935));
    final red = HomeClock.timeShader;

    expect(identical(blue, red), isFalse);
    expect(red(const Rect.fromLTWH(0, 0, 100, 20)), isA<Shader>());
  });

  test('el mismo acento no cambia la función', () {
    HomeClock.setAccent(const Color(0xFF43A047));
    final first = HomeClock.timeShader;
    HomeClock.setAccent(const Color(0xFF43A047));

    expect(identical(first, HomeClock.timeShader), isTrue);
  });

  test('en el modo oscuro es otra función (los títulos se repintan)', () {
    HomeClock.setAccent(const Color(0xFF2B4CFF));
    final light = HomeClock.timeShader;

    HomeClock.setAccent(const Color(0xFF2B4CFF), dark: true);
    final dark = HomeClock.timeShader;

    expect(identical(light, dark), isFalse);
    expect(dark(const Rect.fromLTWH(0, 0, 100, 20)), isA<Shader>());
  });
}
