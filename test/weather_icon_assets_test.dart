import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/weather_icon_mapper.dart';

void main() {
  test('cada ícono del clima que puede pedir la app está en sus assets', () {
    final assets = <String>{
      for (final isDay in [true, false]) ...[
        WeatherIconMapper.getLottieAsset(isDay: isDay),
        // Los códigos de WeatherAPI van de 1000 a 1282.
        for (var code = 1000; code <= 1300; code++)
          WeatherIconMapper.getLottieAsset(code: code, isDay: isDay),
      ],
    };
    for (final asset in assets) {
      expect(asset, startsWith('assets/lottie/weather/'));
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}
