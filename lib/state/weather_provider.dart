import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/weather_icon_mapper.dart';
import 'package:moai3/services/weather_service.dart';

/// Provider responsable de mantener actualizado el clima del dispositivo (TV).
class WeatherProvider extends ChangeNotifier {
  static const String _prefTempKey = 'weather_last_temp_c';
  static const String _prefCityKey = 'weather_last_city';
  static const String _prefCondKey = 'weather_last_condition';
  static const String _prefIconKey = 'weather_last_icon_url';
  static const String _prefCodeKey = 'weather_last_code';
  static const String _prefIsDayKey = 'weather_last_is_day';
  static const String _prefModeKey =
      'weather_location_mode'; // 'auto' | 'custom'
  static const String _prefCustomQueryKey = 'weather_custom_query';
  static const String _prefCustomNameKey = 'weather_custom_name';
  static const Duration _refreshInterval = Duration(minutes: 30);

  final WeatherService _service;
  final AppPreferences _prefs;

  WeatherData? _weather;
  bool _isLoading = false;
  Timer? _timer;

  String _locationMode = 'auto';
  String? _customQuery;
  String? _customName;

  WeatherProvider(this._prefs, {WeatherService? service})
    : _service = service ?? WeatherService() {
    _restoreCachedData();
    refresh();
    _timer = Timer.periodic(_refreshInterval, (_) => refresh());
  }

  WeatherData? get weather => _weather;
  bool get isLoading => _isLoading;
  WeatherService get service => _service;

  /// Indica si la ubicación se determina automáticamente mediante IP / red.
  bool get isAutoLocation => _locationMode == 'auto';

  /// Nombre de la localidad personalizada configurada, o null si está en modo automático.
  String? get customLocationName => _customName;

  /// Nombre legible de la ubicación para mostrar en los paneles de TV.
  String get locationDisplayName {
    if (isAutoLocation) {
      final detectedCity = _weather?.city;
      if (detectedCity != null && detectedCity.isNotEmpty) {
        return 'Automático ($detectedCity)';
      }
      return 'Automático (por red)';
    }
    return _customName ?? _weather?.city ?? '';
  }

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

  /// Retorna la URL CDN del archivo JSON Lottie animado correspondiente al clima actual.
  String get lottieUrl {
    return WeatherIconMapper.getLottieUrl(
      code: _weather?.conditionCode,
      isDay: _weather?.isDay ?? true,
    );
  }

  /// Restaura los últimos datos conocidos de SharedPreferences.
  void _restoreCachedData() {
    _locationMode = _prefs.readOptionalString(_prefModeKey) ?? 'auto';
    _customQuery = _prefs.readOptionalString(_prefCustomQueryKey);
    _customName = _prefs.readOptionalString(_prefCustomNameKey);

    final cachedTemp = _prefs.readOptionalString(_prefTempKey);
    final cachedCity = _prefs.readOptionalString(_prefCityKey);
    final cachedCond = _prefs.readOptionalString(_prefCondKey);
    final cachedIcon = _prefs.readOptionalString(_prefIconKey);
    final cachedCode = _prefs.readOptionalString(_prefCodeKey);
    final cachedIsDay = _prefs.readOptionalString(_prefIsDayKey);

    if (cachedTemp != null) {
      final parsedTemp = double.tryParse(cachedTemp);
      if (parsedTemp != null) {
        _weather = WeatherData(
          tempC: parsedTemp,
          condition: cachedCond ?? '',
          iconUrl: cachedIcon ?? '',
          conditionCode: cachedCode != null ? int.tryParse(cachedCode) : null,
          isDay: cachedIsDay != 'false',
          city: cachedCity ?? '',
          region: '',
          country: '',
          lastUpdated: DateTime.now(),
        );
      }
    }
  }

  bool _isDisposed = false;

  /// Consulta el clima actual (por IP o por localidad configurada) en segundo plano.
  Future<void> refresh() async {
    _isLoading = true;
    if (!_isDisposed) notifyListeners();

    final query =
        (!isAutoLocation &&
            _customQuery != null &&
            _customQuery!.trim().isNotEmpty)
        ? _customQuery!.trim()
        : 'auto:ip';

    try {
      final data = await _service.fetchWeatherByIp(query: query);
      if (_isDisposed) return;

      if (data != null) {
        _weather = data;
        await _prefs.saveString(_prefTempKey, '${data.tempC}');
        await _prefs.saveString(_prefCityKey, data.city);
        await _prefs.saveString(_prefCondKey, data.condition);
        await _prefs.saveString(_prefIconKey, data.iconUrl);
        if (data.conditionCode != null) {
          await _prefs.saveString(_prefCodeKey, '${data.conditionCode}');
        }
        await _prefs.saveString(_prefIsDayKey, '${data.isDay}');
      }
    } catch (e) {
      debugPrint('[WeatherProvider] Error al actualizar el clima: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Configura una localidad manual personalizada seleccionada por el usuario.
  Future<void> setCustomLocation(WeatherLocationSearchResult location) async {
    _locationMode = 'custom';
    _customQuery = location.queryKey;
    _customName = location.displayName;

    await _prefs.saveString(_prefModeKey, 'custom');
    await _prefs.saveString(_prefCustomQueryKey, location.queryKey);
    await _prefs.saveString(_prefCustomNameKey, location.displayName);

    if (!_isDisposed) notifyListeners();
    await refresh();
  }

  /// Restablece la detección de clima al modo automático por IP / red.
  Future<void> resetToAutoLocation() async {
    _locationMode = 'auto';
    _customQuery = null;
    _customName = null;

    await _prefs.saveString(_prefModeKey, 'auto');
    await _prefs.saveString(_prefCustomQueryKey, '');
    await _prefs.saveString(_prefCustomNameKey, '');

    if (!_isDisposed) notifyListeners();
    await refresh();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
