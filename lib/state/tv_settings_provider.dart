import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Provider responsable de los ajustes físicos de la TV (calibración overscan y logs en pantalla).
class TvSettingsProvider extends ChangeNotifier {
  static const String _showTvLogKey = 'show_tv_log';
  static const String _overlapPaddingXKey = 'overlap_padding_x';
  static const String _overlapPaddingYKey = 'overlap_padding_y';
  static const String _hasOverlapConfigKey = 'has_overlap_config';
  static const String _parentalPinKey = 'parental_pin';

  final AppPreferences _prefs;

  late bool _showTvLog;
  late double _overlapPaddingX;
  late double _overlapPaddingY;
  late bool _hasOverlapConfig;

  String? _parentalPin;
  bool _isAdultUnlocked = false;

  TvSettingsProvider(this._prefs) {
    _showTvLog = _prefs.readPreferenceBool(_showTvLogKey);
    _overlapPaddingX =
        _prefs.readPreferenceDouble(_overlapPaddingXKey, defaultValue: 20.0);
    _overlapPaddingY =
        _prefs.readPreferenceDouble(_overlapPaddingYKey, defaultValue: 20.0);
    _hasOverlapConfig = _prefs.readPreferenceBool(_hasOverlapConfigKey);
    _parentalPin = _prefs.readOptionalString(_parentalPinKey);
    _isAdultUnlocked = false; // Siempre bloqueado al iniciar
  }

  bool get showTvLog => _showTvLog;
  double get overlapPaddingX => _overlapPaddingX;
  double get overlapPaddingY => _overlapPaddingY;
  bool get hasOverlapConfig => _hasOverlapConfig;

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
}
