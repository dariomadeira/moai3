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

    test('Open-Meteo encuentra Quines (San Luis) y lo pone primero', () {
      // Respuesta real (recortada) de geocoding-api.open-meteo.com para
      // "Quines": el buscador de WeatherAPI sólo devuelve el de España.
      final body = jsonEncode({
        'results': [
          {
            'name': 'Quinés',
            'latitude': 42.28168,
            'longitude': -8.19743,
            'country': 'España',
            'admin1': 'Comunidad Autónoma de Galicia',
            'admin2': 'Provincia de Ourense',
          },
          {
            'name': 'Quines',
            'latitude': -32.23282,
            'longitude': -65.80507,
            'country': 'Argentina',
            'admin1': 'Provincia de San Luis',
            'admin2': 'Departamento de Ayacucho',
          },
        ],
      });

      final results = WeatherService.parseOpenMeteoSearch(body);

      expect(results, hasLength(2));
      final quines = results.first;
      expect(quines.displayName, equals('Quines, San Luis'));
      expect(quines.subtitle, equals('Ayacucho, San Luis, Argentina'));
      // Sin id de WeatherAPI: el clima se pide por coordenadas.
      expect(quines.queryKey, equals('-32.23282,-65.80507'));
      expect(results.last.country, equals('España'));
    });

    test('Open-Meteo sin resultados devuelve lista vacía', () {
      expect(WeatherService.parseOpenMeteoSearch('{}'), isEmpty);
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
      final translations =
          jsonDecode(File('assets/translations/es.json').readAsStringSync())
              as Map<String, dynamic>;
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

    test('restaura pronóstico completo desde caché JSON', () async {
      final sampleJson = {
        'location': {'name': 'Quines', 'region': 'San Luis', 'country': 'Argentina'},
        'current': {
          'temp_c': 17.0,
          'feelslike_c': 16.0,
          'is_day': 1,
          'condition': {'text': 'Cubierto', 'code': 1009, 'icon': '//cdn.weatherapi.com/icon.png'},
        },
        'forecast': {
          'forecastday': [
            {
              'day': {'maxtemp_c': 22.0, 'mintemp_c': 11.0, 'daily_chance_of_rain': 20},
              'hour': [
                {
                  'time_epoch': 1792983600,
                  'temp_c': 17.0,
                  'is_day': 1,
                  'condition': {'code': 1009},
                  'chance_of_rain': 20,
                },
                {
                  'time_epoch': 1792987200,
                  'temp_c': 16.5,
                  'is_day': 1,
                  'condition': {'code': 1009},
                  'chance_of_rain': 10,
                },
              ],
            },
          ],
        },
      };

      await prefs.saveString('weather_last_full_json', jsonEncode(sampleJson));

      final provider = WeatherProvider(prefs, enableTimer: false);
      expect(provider.weather, isNotNull);
      expect(provider.weather!.city, equals('Quines'));
      expect(provider.weather!.tempC, equals(17.0));
      expect(provider.weather!.feelsLikeC, equals(16.0));
      expect(provider.weather!.maxTempC, equals(22.0));
      expect(provider.weather!.minTempC, equals(11.0));
      expect(provider.weather!.hourly, hasLength(2));
      expect(provider.weather!.rawJson, isNotNull);
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
