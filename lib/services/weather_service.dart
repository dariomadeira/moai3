import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/config/constants.dart';

/// Modelo de datos para el clima actual.
class WeatherData {
  final double tempC;
  final String condition;
  final String iconUrl;
  final int? conditionCode;
  final bool isDay;
  final String city;
  final String region;
  final String country;
  final int? humidity;
  final DateTime lastUpdated;

  /// Sensación térmica actual.
  final double? feelsLikeC;

  /// Máxima, mínima y probabilidad de lluvia del día (del pronóstico).
  final double? maxTempC;
  final double? minTempC;
  final int? chanceOfRain;

  /// Pronóstico por hora de hoy y mañana, en orden. Vacío si la respuesta no
  /// trae pronóstico (p. ej. datos restaurados de caché).
  final List<WeatherHour> hourly;

  const WeatherData({
    required this.tempC,
    required this.condition,
    required this.iconUrl,
    this.conditionCode,
    this.isDay = true,
    required this.city,
    required this.region,
    required this.country,
    this.humidity,
    required this.lastUpdated,
    this.feelsLikeC,
    this.maxTempC,
    this.minTempC,
    this.chanceOfRain,
    this.hourly = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>? ?? {};
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final cond = current['condition'] as Map<String, dynamic>? ?? {};

    String rawIcon = cond['icon'] as String? ?? '';
    if (rawIcon.startsWith('//')) {
      rawIcon = 'https:$rawIcon';
    }

    final isDayInt = (current['is_day'] as num?)?.toInt() ?? 1;

    final forecast = json['forecast'] as Map<String, dynamic>? ?? {};
    final days = (forecast['forecastday'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final today = days.isEmpty
        ? const <String, dynamic>{}
        : days.first['day'] as Map<String, dynamic>? ?? const {};

    return WeatherData(
      feelsLikeC: (current['feelslike_c'] as num?)?.toDouble(),
      maxTempC: (today['maxtemp_c'] as num?)?.toDouble(),
      minTempC: (today['mintemp_c'] as num?)?.toDouble(),
      chanceOfRain: (today['daily_chance_of_rain'] as num?)?.toInt(),
      hourly: [
        for (final day in days)
          for (final hour in day['hour'] as List<dynamic>? ?? const [])
            if (hour is Map<String, dynamic>) WeatherHour.fromJson(hour),
      ],
      tempC: (current['temp_c'] as num?)?.toDouble() ?? 0.0,
      condition: cond['text'] as String? ?? '',
      iconUrl: rawIcon,
      conditionCode: (cond['code'] as num?)?.toInt(),
      isDay: isDayInt == 1,
      city: location['name'] as String? ?? '',
      region: location['region'] as String? ?? '',
      country: location['country'] as String? ?? '',
      humidity: (current['humidity'] as num?)?.toInt(),
      lastUpdated: DateTime.now(),
    );
  }

  int get formattedTemp => tempC.round();

  /// Las próximas [count] horas empezando por la hora en curso.
  List<WeatherHour> upcomingHours(DateTime now, {int count = 8}) {
    final currentHour = DateTime(now.year, now.month, now.day, now.hour);
    return hourly
        .where((h) => !h.time.isBefore(currentHour))
        .take(count)
        .toList();
  }
}

/// Una hora del pronóstico.
class WeatherHour {
  /// Hora local del aparato.
  final DateTime time;
  final double tempC;
  final int? conditionCode;
  final bool isDay;
  final int? chanceOfRain;

  const WeatherHour({
    required this.time,
    required this.tempC,
    this.conditionCode,
    this.isDay = true,
    this.chanceOfRain,
  });

  factory WeatherHour.fromJson(Map<String, dynamic> json) {
    final cond = json['condition'] as Map<String, dynamic>? ?? {};
    final epoch = (json['time_epoch'] as num?)?.toInt() ?? 0;
    return WeatherHour(
      time: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
      tempC: (json['temp_c'] as num?)?.toDouble() ?? 0.0,
      conditionCode: (cond['code'] as num?)?.toInt(),
      isDay: ((json['is_day'] as num?)?.toInt() ?? 1) == 1,
      chanceOfRain: (json['chance_of_rain'] as num?)?.toInt(),
    );
  }

  int get formattedTemp => tempC.round();
}

/// Representa el resultado de una búsqueda o sugerencia de localidad en WeatherAPI.
class WeatherLocationSearchResult {
  final int id;
  final String name;
  final String region;
  final String country;
  final double lat;
  final double lon;

  /// Departamento o partido (sólo de Open-Meteo), para distinguir pueblos
  /// con el mismo nombre.
  final String area;

  const WeatherLocationSearchResult({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    required this.lat,
    required this.lon,
    this.area = '',
  });

  /// De la búsqueda de Open-Meteo (GeoNames), que conoce pueblos que la de
  /// WeatherAPI no (p. ej. Quines, San Luis). Sin id de WeatherAPI: el clima
  /// se pide por coordenadas.
  factory WeatherLocationSearchResult.fromOpenMeteo(Map<String, dynamic> json) {
    String clean(Object? s) => (s?.toString() ?? '')
        .replaceFirst(
          RegExp(r'^(Provincia|Departamento) del? ', caseSensitive: false),
          '',
        )
        .trim();
    return WeatherLocationSearchResult(
      id: 0,
      name: json['name']?.toString() ?? '',
      region: clean(json['admin1']),
      country: json['country']?.toString() ?? '',
      lat: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      lon: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      area: clean(json['admin2']),
    );
  }

  /// Es de Argentina (va primero en la búsqueda).
  bool get isArgentina => country == 'Argentina';

  static String _sanitize(String input) {
    if (input.isEmpty || !input.contains('Ã')) return input;
    try {
      return utf8.decode(latin1.encode(input));
    } catch (_) {
      return input;
    }
  }

  factory WeatherLocationSearchResult.fromJson(Map<String, dynamic> json) {
    return WeatherLocationSearchResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: _sanitize(json['name'] as String? ?? ''),
      region: _sanitize(json['region'] as String? ?? ''),
      country: _sanitize(json['country'] as String? ?? ''),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      area: _sanitize(json['area'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'country': country,
      'lat': lat,
      'lon': lon,
      if (area.isNotEmpty) 'area': area,
    };
  }

  /// Retorna la clave de consulta óptima para WeatherAPI (ej. 'id:105813' o coordenadas).
  String get queryKey => id > 0 ? 'id:$id' : '$lat,$lon';

  /// Nombre formateado para mostrar en interfaz de TV (ej: "Villa Carlos Paz, Córdoba").
  String get displayName {
    if (region.isNotEmpty && region.toLowerCase() != name.toLowerCase()) {
      return '$name, $region';
    }
    return name;
  }

  /// Detalle secundario con departamento, provincia y país (ej: "Ayacucho,
  /// San Luis, Argentina").
  String get subtitle {
    final parts = <String>[];
    if (area.isNotEmpty && area.toLowerCase() != name.toLowerCase()) {
      parts.add(area);
    }
    if (region.isNotEmpty) parts.add(region);
    if (country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}

/// Servicio que consulta la API de WeatherAPI tanto por auto:ip como por búsqueda
/// de localidades específicas con autocompletado en tiempo real.
class WeatherService {
  /// forecast.json trae lo mismo que current.json más el pronóstico por hora:
  /// sigue siendo una sola consulta. Dos días para cubrir las horas que
  /// cruzan la medianoche.
  static const String _baseUrl = 'https://api.weatherapi.com/v1/forecast.json';
  static const String _searchUrl = 'https://api.weatherapi.com/v1/search.json';

  /// Buscador de localidades de Open-Meteo (gratis, sin clave).
  static const String _geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  String get _apiKey => kWeatherApiKey;

  Future<WeatherData?> fetchWeatherByIp({String query = 'auto:ip'}) async {
    if (_apiKey.isEmpty) {
      debugPrint(
        '[WeatherService] WEATHER_API_KEY vacía; se omite la consulta',
      );
      return null;
    }
    try {
      final safeQuery = query.trim().isEmpty ? 'auto:ip' : query.trim();
      final url = Uri.parse(
        '$_baseUrl?key=$_apiKey&q=${Uri.encodeQueryComponent(safeQuery)}'
        '&days=2&aqi=no&alerts=no&lang=es',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(url);
      request.headers.set('Accept', 'application/json');
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        return WeatherData.fromJson(data);
      } else {
        debugPrint('[WeatherService] Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[WeatherService] Error al consultar el clima: $e');
    }
    return null;
  }

  /// Busca localidades para el texto ingresado: primero en Open-Meteo, que
  /// tiene los pueblos chicos (el buscador de WeatherAPI no encuentra, p. ej.,
  /// Quines en San Luis); si falla o no encuentra nada, en WeatherAPI.
  Future<List<WeatherLocationSearchResult>> searchLocations(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];
    final found = await _searchOpenMeteo(trimmed);
    if (found.isNotEmpty) return found;
    return _searchWeatherApi(trimmed);
  }

  Future<List<WeatherLocationSearchResult>> _searchOpenMeteo(
    String query,
  ) async {
    try {
      final url = Uri.parse(
        '$_geocodingUrl?name=${Uri.encodeQueryComponent(query)}'
        '&count=10&language=es&format=json',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(url);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return const [];
      final body = await response.transform(utf8.decoder).join();
      return parseOpenMeteoSearch(body);
    } catch (e) {
      debugPrint('[WeatherService] Error al buscar en Open-Meteo: $e');
      return const [];
    }
  }

  /// Resultados de Open-Meteo, los de Argentina primero (sin cambiar el
  /// orden de relevancia dentro de cada grupo).
  @visibleForTesting
  static List<WeatherLocationSearchResult> parseOpenMeteoSearch(String body) {
    final data = json.decode(body);
    final results = data is Map<String, dynamic> ? data['results'] : null;
    if (results is! List) return const [];
    final all = [
      for (final r in results)
        if (r is Map<String, dynamic>)
          WeatherLocationSearchResult.fromOpenMeteo(r),
    ];
    return [
      ...all.where((r) => r.isArgentina),
      ...all.where((r) => !r.isArgentina),
    ];
  }

  Future<List<WeatherLocationSearchResult>> _searchWeatherApi(
    String trimmed,
  ) async {
    if (_apiKey.isEmpty) {
      debugPrint(
        '[WeatherService] WEATHER_API_KEY vacía; se omite la búsqueda',
      );
      return const [];
    }

    try {
      final url = Uri.parse(
        '$_searchUrl?key=$_apiKey&q=${Uri.encodeQueryComponent(trimmed)}&lang=es',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(url);
      request.headers.set('Accept', 'application/json');
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      );

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = json.decode(body) as List<dynamic>;
        return list
            .map(
              (item) => WeatherLocationSearchResult.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('[WeatherService] Error al buscar localidades: $e');
    }
    return const [];
  }
}
