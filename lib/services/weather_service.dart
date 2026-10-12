import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

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

    return WeatherData(
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
}

/// Representa el resultado de una búsqueda o sugerencia de localidad en WeatherAPI.
class WeatherLocationSearchResult {
  final int id;
  final String name;
  final String region;
  final String country;
  final double lat;
  final double lon;

  const WeatherLocationSearchResult({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    required this.lat,
    required this.lon,
  });

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

  /// Detalle secundario con provincia y país (ej: "Córdoba, Argentina").
  String get subtitle {
    final parts = <String>[];
    if (region.isNotEmpty) parts.add(region);
    if (country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}

/// Servicio que consulta la API de WeatherAPI tanto por auto:ip como por búsqueda
/// de localidades específicas con autocompletado en tiempo real.
class WeatherService {
  static const String _apiKey = 'ec23b57a160c4d07a70125728212705';
  static const String _baseUrl = 'https://api.weatherapi.com/v1/current.json';
  static const String _searchUrl = 'https://api.weatherapi.com/v1/search.json';

  Future<WeatherData?> fetchWeatherByIp({String query = 'auto:ip'}) async {
    try {
      final safeQuery = query.trim().isEmpty ? 'auto:ip' : query.trim();
      final url = Uri.parse(
        '$_baseUrl?key=$_apiKey&q=${Uri.encodeQueryComponent(safeQuery)}&lang=es',
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

  /// Busca sugerencias de localidades en tiempo real a partir del texto ingresado.
  Future<List<WeatherLocationSearchResult>> searchLocations(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

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
