import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/weather_service.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WeatherLocationSearchResult Model Tests', () {
    test('fromJson y displayName formatean correctamente', () {
      final json = {
        'id': 112128,
        'name': 'Villa Carlos Paz',
        'region': 'Cordoba',
        'country': 'Argentina',
        'lat': -31.4,
        'lon': -64.52,
      };

      final result = WeatherLocationSearchResult.fromJson(json);

      expect(result.id, equals(112128));
      expect(result.name, equals('Villa Carlos Paz'));
      expect(result.region, equals('Cordoba'));
      expect(result.country, equals('Argentina'));
      expect(result.queryKey, equals('id:112128'));
      expect(result.displayName, equals('Villa Carlos Paz, Cordoba'));
      expect(result.subtitle, equals('Cordoba, Argentina'));
    });

    test('displayName omite region si coincide con name', () {
      final json = {
        'id': 105813,
        'name': 'Cordoba',
        'region': 'Cordoba',
        'country': 'Argentina',
        'lat': -31.4,
        'lon': -64.18,
      };

      final result = WeatherLocationSearchResult.fromJson(json);
      expect(result.displayName, equals('Cordoba'));
    });
  });

  group('WeatherProvider Location Mode Tests', () {
    late AppPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.init();
    });

    test('Modo inicial es auto:ip', () {
      final provider = WeatherProvider(prefs);
      expect(provider.isAutoLocation, isTrue);
      expect(provider.customLocationName, isNull);
      expect(provider.locationDisplayName, 'weather_auto_network');
      final translations = jsonDecode(
        File('assets/translations/es.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(translations['weather_auto_network'], contains('Automático'));
      provider.dispose();
    });

    test('en automático muestra la ciudad (región), no el barrio', () async {
      final provider = WeatherProvider(
        prefs,
        service: _FixedWeather(),
        enableTimer: false,
      );
      await provider.refresh();
      // WeatherAPI ubica la IP en un barrio de São Paulo.
      expect(provider.placeName, 'Sao Paulo');
      provider.dispose();
    });

    test('con una localidad elegida muestra su nombre', () async {
      final provider = WeatherProvider(
        prefs,
        service: _FixedWeather(),
        enableTimer: false,
      );
      await provider.setCustomLocation(
        const WeatherLocationSearchResult(
          id: 1,
          name: 'Cosquin',
          region: 'Cordoba',
          country: 'Argentina',
          lat: 0,
          lon: 0,
        ),
      );
      expect(provider.placeName, 'Cosquin, Cordoba');
      provider.dispose();
    });

    test('setCustomLocation guarda y conmuta a modo custom', () async {
      final provider = WeatherProvider(prefs);

      const loc = WeatherLocationSearchResult(
        id: 105911,
        name: 'Cosquin',
        region: 'Cordoba',
        country: 'Argentina',
        lat: -31.25,
        lon: -64.48,
      );

      await provider.setCustomLocation(loc);

      expect(provider.isAutoLocation, isFalse);
      expect(provider.customLocationName, equals('Cosquin, Cordoba'));
      expect(provider.locationDisplayName, equals('Cosquin, Cordoba'));

      // Verificar persistencia en preferences
      expect(
        prefs.readOptionalString('weather_location_mode'),
        equals('custom'),
      );
      expect(
        prefs.readOptionalString('weather_custom_query'),
        equals('id:105911'),
      );
      expect(
        prefs.readOptionalString('weather_custom_name'),
        equals('Cosquin, Cordoba'),
      );

      // Restablecer a auto
      await provider.resetToAutoLocation();
      expect(provider.isAutoLocation, isTrue);
      expect(provider.customLocationName, isNull);
      expect(prefs.readOptionalString('weather_location_mode'), equals('auto'));

      provider.dispose();
    });
  });
}

/// Clima fijo: la IP cae en el barrio Liberdade de São Paulo.
class _FixedWeather extends WeatherService {
  @override
  Future<WeatherData?> fetchWeatherByIp({String query = 'auto:ip'}) async =>
      WeatherData(
        tempC: 18,
        condition: 'Lluvia ligera',
        iconUrl: '',
        city: 'Liberdade',
        region: 'Sao Paulo',
        country: 'Brazil',
        lastUpdated: DateTime(2026, 10, 25),
      );
}
