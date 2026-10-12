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
