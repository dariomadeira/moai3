import 'dart:math';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/theme/moai_accent_colors.dart';

/// Provider responsable de la apariencia visual (modo oscuro y color de acento).
class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode';
  static const String _accentColorIndexKey = 'accent_color_index';
  static const String _autoAccentKey = 'auto_accent_color';

  final AppPreferences _prefs;
  late bool _darkMode;
  late bool _autoAccent;
  late int _accentColorIndex;

  ThemeProvider(this._prefs) {
    _darkMode = _prefs.readPreferenceBool(_darkModeKey, defaultValue: true);
    _autoAccent = _prefs.readPreferenceBool(_autoAccentKey, defaultValue: false);
    final savedManualIndex = MoaiAccentColors.clampIndex(
      _prefs.readPreferenceInt(_accentColorIndexKey),
    );
    if (_autoAccent) {
      _accentColorIndex = Random().nextInt(MoaiAccentColors.seeds.length);
    } else {
      _accentColorIndex = savedManualIndex;
    }
  }

  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  bool get autoAccent => _autoAccent;
  int get accentColorIndex => _accentColorIndex;
  Color get accentSeed => MoaiAccentColors.seedAt(_accentColorIndex);

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    await _prefs.saveBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setAutoAccent(bool value) async {
    if (_autoAccent == value) return;
    _autoAccent = value;
    await _prefs.saveBool(_autoAccentKey, value);
    if (value) {
      _accentColorIndex = Random().nextInt(MoaiAccentColors.seeds.length);
    } else {
      _accentColorIndex = MoaiAccentColors.clampIndex(
        _prefs.readPreferenceInt(_accentColorIndexKey),
      );
    }
    notifyListeners();
  }

  Future<void> setAccentColorIndex(int index) async {
    final next = MoaiAccentColors.clampIndex(index);
    await _prefs.saveInt(_accentColorIndexKey, next);
    if (_accentColorIndex == next) return;
    _accentColorIndex = next;
    notifyListeners();
  }
}
