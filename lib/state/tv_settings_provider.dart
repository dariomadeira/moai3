import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Frecuencia con la que el arranque intenta sincronizar el catálogo Moiamov.
enum CatalogUpdateFrequency {
  always('always'),
  weekly('weekly'),
  monthly('monthly');

  const CatalogUpdateFrequency(this.storageValue);
  final String storageValue;

  static const CatalogUpdateFrequency defaultValue =
      CatalogUpdateFrequency.weekly;

  static const List<CatalogUpdateFrequency> options = [
    CatalogUpdateFrequency.always,
    CatalogUpdateFrequency.weekly,
    CatalogUpdateFrequency.monthly,
  ];

  static CatalogUpdateFrequency fromStorage(String? raw) {
    for (final value in CatalogUpdateFrequency.values) {
      if (value.storageValue == raw) return value;
    }
    return defaultValue;
  }
}

/// Idioma del audio para películas y series. Los streams traen varios audios
/// juntos (p. ej. "spa,spa,eng"); se elige uno para todo en vez de cambiarlo
/// en cada película.
enum MovieAudioLanguage {
  spanish('spanish'),
  english('english'),

  /// El que no es español (el de la filmación); si sólo hay español, ése.
  original('original');

  const MovieAudioLanguage(this.storageValue);
  final String storageValue;

  static const MovieAudioLanguage defaultValue = MovieAudioLanguage.spanish;

  static MovieAudioLanguage fromStorage(String? raw) {
    for (final value in MovieAudioLanguage.values) {
      if (value.storageValue == raw) return value;
    }
    return defaultValue;
  }
}

/// Subtítulos de películas y series: uno para todo, como el audio.
enum MovieSubtitleLanguage {
  off('off'),
  spanish('spanish'),
  english('english');

  const MovieSubtitleLanguage(this.storageValue);
  final String storageValue;

  static const MovieSubtitleLanguage defaultValue = MovieSubtitleLanguage.off;

  static MovieSubtitleLanguage fromStorage(String? raw) {
    for (final value in MovieSubtitleLanguage.values) {
      if (value.storageValue == raw) return value;
    }
    return defaultValue;
  }
}

/// Provider responsable de los ajustes físicos de la TV (calibración overscan y logs en pantalla).
class TvSettingsProvider extends ChangeNotifier {
  static const String _showTvLogKey = 'show_tv_log';
  static const String _showChannelLabelsKey = 'show_channel_labels';
  static const String _overlapPaddingXKey = 'overlap_padding_x';
  static const String _overlapPaddingYKey = 'overlap_padding_y';
  static const String _hasOverlapConfigKey = 'has_overlap_config';
  static const String _parentalPinKey = 'parental_pin';
  static const String _uiSoundsDisabledKey = 'ui_sounds_disabled';
  static const String _showHomeTrailersKey = 'home_show_trailers';
  static const String _catalogUpdateFrequencyKey = 'catalog_update_frequency';
  static const String _startupTvTabKey = 'startup_tv_tab';
  static const String _movieAudioLanguageKey = 'movie_audio_language';
  static const String _movieSubtitleLanguageKey = 'movie_subtitle_language';

  static const MethodChannel _deviceChannel =
      PlatformChannels.device;

  final AppPreferences _prefs;

  late bool _showTvLog;
  late bool _showChannelLabels;
  late double _overlapPaddingX;
  late double _overlapPaddingY;
  late bool _hasOverlapConfig;
  late bool _uiSoundsDisabled;
  late bool _showHomeTrailers;
  late CatalogUpdateFrequency _catalogUpdateFrequency;
  late TvTab _startupTvTab;
  late MovieAudioLanguage _movieAudioLanguage;
  late MovieSubtitleLanguage _movieSubtitleLanguage;

  String? _parentalPin;
  bool _isAdultUnlocked = false;

  TvSettingsProvider(this._prefs) {
    _showTvLog = _prefs.readPreferenceBool(_showTvLogKey);
    _showChannelLabels =
        _prefs.readPreferenceBool(_showChannelLabelsKey); // default false
    _overlapPaddingX =
        _prefs.readPreferenceDouble(_overlapPaddingXKey, defaultValue: 20.0);
    _overlapPaddingY =
        _prefs.readPreferenceDouble(_overlapPaddingYKey, defaultValue: 20.0);
    _hasOverlapConfig = _prefs.readPreferenceBool(_hasOverlapConfigKey);
    _uiSoundsDisabled = _prefs.readPreferenceBool(
      _uiSoundsDisabledKey,
    );
    _showHomeTrailers = _prefs.readPreferenceBool(
      _showHomeTrailersKey,
      defaultValue: true,
    );
    _catalogUpdateFrequency = CatalogUpdateFrequency.fromStorage(
      _prefs.readOptionalString(_catalogUpdateFrequencyKey),
    );
    _startupTvTab = TvTab.fromStorage(
      _prefs.readOptionalString(_startupTvTabKey),
    );
    _movieAudioLanguage = MovieAudioLanguage.fromStorage(
      _prefs.readOptionalString(_movieAudioLanguageKey),
    );
    _movieSubtitleLanguage = MovieSubtitleLanguage.fromStorage(
      _prefs.readOptionalString(_movieSubtitleLanguageKey),
    );
    _parentalPin = _prefs.readOptionalString(_parentalPinKey);
    _isAdultUnlocked = false; // Siempre bloqueado al iniciar
    _syncUiSoundsToNative();
  }

  bool get showTvLog => _showTvLog;
  bool get showChannelLabels => _showChannelLabels;
  double get overlapPaddingX => _overlapPaddingX;
  double get overlapPaddingY => _overlapPaddingY;
  bool get hasOverlapConfig => _hasOverlapConfig;
  TvTab get startupTvTab => _startupTvTab;

  /// Si es true, no se reproducen los WAV de clicks D-pad de la interfaz.
  bool get uiSoundsDisabled => _uiSoundsDisabled;

  /// La tarjeta "Adelantos" del Inicio (Ajustes › Películas y series). Se
  /// ve salvo que se apague.
  bool get showHomeTrailers => _showHomeTrailers;

  /// Cada cuánto el arranque intenta sync cuando la actualización está activa.
  CatalogUpdateFrequency get catalogUpdateFrequency => _catalogUpdateFrequency;

  MovieAudioLanguage get movieAudioLanguage => _movieAudioLanguage;

  MovieSubtitleLanguage get movieSubtitleLanguage => _movieSubtitleLanguage;

  /// Decide si el arranque debe intentar VPN+sync según fecha y frecuencia.
  ///
  /// Sin [savedAt] o con [CatalogUpdateFrequency.always] → siempre true.
  static bool shouldAttemptCatalogUpdate({
    required DateTime? savedAt,
    required CatalogUpdateFrequency frequency,
    DateTime? now,
  }) {
    if (frequency == CatalogUpdateFrequency.always || savedAt == null) {
      return true;
    }
    final reference = now ?? DateTime.now();
    final maxAge = switch (frequency) {
      CatalogUpdateFrequency.always => Duration.zero,
      CatalogUpdateFrequency.weekly => const Duration(days: 7),
      CatalogUpdateFrequency.monthly => const Duration(days: 30),
    };
    return !reference.isBefore(savedAt.add(maxAge));
  }

  bool get isAdultUnlocked => _isAdultUnlocked;
  bool get hasParentalPin =>
      _parentalPin != null && _parentalPin!.trim().isNotEmpty;

  bool verifyPin(String pin) {
    if (!hasParentalPin) return false;
    return _parentalPin == pin.trim();
  }

  Future<void> setParentalPin(String newPin) async {
    final clean = newPin.trim();
    _parentalPin = clean;
    await _prefs.saveString(_parentalPinKey, clean);
    notifyListeners();
  }

  void unlockAdultForSession() {
    if (_isAdultUnlocked) return;
    _isAdultUnlocked = true;
    notifyListeners();
  }

  void lockAdult() {
    if (!_isAdultUnlocked) return;
    _isAdultUnlocked = false;
    notifyListeners();
  }

  Future<void> setOverlapConfig({
    required double x,
    required double y,
  }) async {
    _overlapPaddingX = x;
    _overlapPaddingY = y;
    _hasOverlapConfig = true;
    await _prefs.saveDouble(_overlapPaddingXKey, x);
    await _prefs.saveDouble(_overlapPaddingYKey, y);
    await _prefs.saveBool(_hasOverlapConfigKey, true);
    notifyListeners();
  }

  Future<void> setShowTvLog(bool value) async {
    if (_showTvLog == value) return;
    _showTvLog = value;
    await _prefs.saveBool(_showTvLogKey, value);
    notifyListeners();
  }

  Future<void> setShowChannelLabels(bool value) async {
    if (_showChannelLabels == value) return;
    _showChannelLabels = value;
    await _prefs.saveBool(_showChannelLabelsKey, value);
    notifyListeners();
  }

  Future<void> setShowHomeTrailers(bool value) async {
    if (_showHomeTrailers == value) return;
    _showHomeTrailers = value;
    await _prefs.saveBool(_showHomeTrailersKey, value);
    notifyListeners();
  }

  Future<void> setUiSoundsDisabled(bool value) async {
    if (_uiSoundsDisabled == value) return;
    _uiSoundsDisabled = value;
    await _prefs.saveBool(_uiSoundsDisabledKey, value);
    await _syncUiSoundsToNative();
    notifyListeners();
  }

  Future<void> setCatalogUpdateFrequency(CatalogUpdateFrequency value) async {
    if (_catalogUpdateFrequency == value) return;
    _catalogUpdateFrequency = value;
    await _prefs.saveString(_catalogUpdateFrequencyKey, value.storageValue);
    notifyListeners();
  }

  Future<void> setMovieAudioLanguage(MovieAudioLanguage value) async {
    if (_movieAudioLanguage == value) return;
    _movieAudioLanguage = value;
    await _prefs.saveString(_movieAudioLanguageKey, value.storageValue);
    notifyListeners();
  }

  Future<void> setMovieSubtitleLanguage(MovieSubtitleLanguage value) async {
    if (_movieSubtitleLanguage == value) return;
    _movieSubtitleLanguage = value;
    await _prefs.saveString(_movieSubtitleLanguageKey, value.storageValue);
    notifyListeners();
  }

  Future<void> setStartupTvTab(TvTab value) async {
    if (_startupTvTab == value) return;
    _startupTvTab = value;
    await _prefs.saveString(_startupTvTabKey, value.name);
    notifyListeners();
  }

  Future<void> _syncUiSoundsToNative() async {
    try {
      await _deviceChannel.invokeMethod<void>(
        'setUiDpadSoundsEnabled',
        {'enabled': !_uiSoundsDisabled},
      );
    } catch (e) {
      // No-Android / canal no listo: ignorar.
      debugPrint('TvSettingsProvider: sync UI sounds failed: $e');
    }
  }
}
