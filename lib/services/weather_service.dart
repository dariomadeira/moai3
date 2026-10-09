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

/// Servicio que consulta la API de WeatherAPI utilizando auto:ip para determinar
/// automáticamente la ubicación física del dispositivo (TV) sin intervención del usuario.
class WeatherService {
  static const String _apiKey = 'ec23b57a160c4d07a70125728212705';
  static const String _baseUrl = 'https://api.weatherapi.com/v1/current.json';

  Future<WeatherData?> fetchWeatherByIp({String query = 'auto:ip'}) async {
    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey&q=$query&lang=es');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
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
}
