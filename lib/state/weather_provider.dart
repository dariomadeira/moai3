import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/weather_service.dart';

/// Provider responsable de mantener actualizado el clima del dispositivo (TV).
class WeatherProvider extends ChangeNotifier {
  static const String _prefTempKey = 'weather_last_temp_c';
  static const String _prefCityKey = 'weather_last_city';
  static const String _prefCondKey = 'weather_last_condition';
  static const String _prefIconKey = 'weather_last_icon_url';
  static const Duration _refreshInterval = Duration(minutes: 30);

  final WeatherService _service;
  final AppPreferences _prefs;

  WeatherData? _weather;
  bool _isLoading = false;
  Timer? _timer;

  WeatherProvider(
    this._prefs, {
    WeatherService? service,
  }) : _service = service ?? WeatherService() {
    _restoreCachedData();
    refresh();
    _timer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  WeatherData? get weather => _weather;
  bool get isLoading => _isLoading;

  /// Retorna la representación formateada de la temperatura (ej: "21°" o "33°" si está cargando por primera vez).
  String get temperatureDisplay {
    if (_weather != null) {
      return '${_weather!.formattedTemp}°';
    }
    return '33°'; // Fallback por defecto mientras se obtiene la ubicación
  }

  /// Ciudad actual o cadena vacía si no se ha cargado.
  String get cityDisplay => _weather?.city ?? '';

  /// Condición meteorológica (ej: "Soleado", "Lluvia").
  String get conditionDisplay => _weather?.condition ?? '';

  /// URL del icono del clima actual.
  String get iconUrlDisplay => _weather?.iconUrl ?? '';

  /// Restaura los últimos datos conocidos de SharedPreferences.
  void _restoreCachedData() {
    final cachedTemp = _prefs.readOptionalString(_prefTempKey);
    final cachedCity = _prefs.readOptionalString(_prefCityKey);
    final cachedCond = _prefs.readOptionalString(_prefCondKey);
    final cachedIcon = _prefs.readOptionalString(_prefIconKey);

    if (cachedTemp != null) {
      final parsedTemp = double.tryParse(cachedTemp);
      if (parsedTemp != null) {
        _weather = WeatherData(
          tempC: parsedTemp,
          condition: cachedCond ?? '',
          iconUrl: cachedIcon ?? '',
          city: cachedCity ?? '',
          region: '',
          country: '',
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  /// Consulta el clima actual por IP en segundo plano.
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    final data = await _service.fetchWeatherByIp();
    if (data != null) {
      _weather = data;
      await _prefs.saveString(_prefTempKey, '${data.tempC}');
      await _prefs.saveString(_prefCityKey, data.city);
      await _prefs.saveString(_prefCondKey, data.condition);
      await _prefs.saveString(_prefIconKey, data.iconUrl);
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
