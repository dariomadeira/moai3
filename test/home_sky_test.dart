import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_sky.dart';

void main() {
  HomeSkyColors at(int hour, {int? code}) =>
      HomeSkyColors.at(DateTime(2026, 10, 25, hour), weatherCode: code);

  test('cada momento del día tiene su color', () {
    final dawn = at(6), day = at(12), dusk = at(18), night = at(23);
    expect({dawn, day, dusk, night}, hasLength(4));
    // La madrugada es noche.
    expect(at(3), night);
  });

  test('de noche el cielo es violeta (más azul que rojo)', () {
    final night = at(22).main;
    expect(night.b, greaterThan(night.r));
  });

  test('con lluvia se apaga y con sol queda igual', () {
    const clear = 1000, rain = 1189;
    expect(at(12, code: clear), at(12));
    final rainy = at(12, code: rain).main;
    final sunny = at(12).main;
    // Más cerca del gris: menos diferencia entre canales.
    double spread(Color c) =>
        [c.r, c.g, c.b].reduce((a, b) => a > b ? a : b) -
        [c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
    expect(spread(rainy), lessThan(spread(sunny)));
  });

  test('clasifica el tiempo por código', () {
    expect(weatherKindOf(1000), WeatherKind.clear);
    expect(weatherKindOf(1189), WeatherKind.rain);
    expect(weatherKindOf(1225), WeatherKind.snow);
    expect(weatherKindOf(1009), WeatherKind.cloudy);
  });

  group('foto del cielo', () {
    HomeSkyScene scene(int hour, {int? code}) =>
        HomeSkyScene.at(DateTime(2026, 10, 25, hour), weatherCode: code);
    const sunny = 1000, cloudy = 1009, rain = 1189, storm = 1276;
    const snow = 1225;

    test('con buen tiempo, la de la hora', () {
      expect(scene(6, code: sunny), HomeSkyScene.dawn);
      expect(scene(12, code: sunny), HomeSkyScene.day);
      expect(scene(18, code: sunny), HomeSkyScene.dusk);
      expect(scene(23, code: sunny), HomeSkyScene.night);
      expect(scene(3), HomeSkyScene.night);
    });

    test(
      'nublado: gris de día; al amanecer, atardecer y noche, la de la hora',
      () {
        expect(scene(12, code: cloudy), HomeSkyScene.cloudy);
        expect(scene(6, code: cloudy), HomeSkyScene.dawn);
        expect(scene(18, code: cloudy), HomeSkyScene.dusk);
        expect(scene(22, code: cloudy), HomeSkyScene.night);
      },
    );

    test('lluvia: gris de día, ventana con lluvia de noche', () {
      expect(scene(12, code: rain), HomeSkyScene.cloudy);
      expect(scene(22, code: rain), HomeSkyScene.nightRain);
    });

    test('tormenta y nieve mandan a cualquier hora', () {
      expect(scene(12, code: storm), HomeSkyScene.storm);
      expect(scene(23, code: storm), HomeSkyScene.storm);
      expect(scene(7, code: snow), HomeSkyScene.snow);
    });

    test('cada escena tiene su archivo en assets', () {
      for (final s in HomeSkyScene.values) {
        expect(File(s.asset).existsSync(), isTrue, reason: s.asset);
      }
    });
  });

  testWidgets('la foto ocupa todo el ancho y el alto de arriba', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 800,
            height: 500,
            child: HomeSkyBackdrop(time: DateTime(2026, 10, 25, 23)),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(Image));
    expect(size.width, 800);
    expect(size.height, closeTo(500 * 0.62, 0.5));
  });
}
