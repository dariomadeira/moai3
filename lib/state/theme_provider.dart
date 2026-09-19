import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/theme/moai_accent_colors.dart';

/// Provider responsable de la apariencia visual (modo oscuro y color de acento).
class ThemeProvider extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode';
  static const String _accentColorIndexKey = 'accent_color_index';

  final AppPreferences _prefs;
  late bool _darkMode;
  late int _accentColorIndex;

  ThemeProvider(this._prefs) {
    _darkMode = _prefs.readPreferenceBool(_darkModeKey, defaultValue: true);
    _accentColorIndex = MoaiAccentColors.clampIndex(
      _prefs.readPreferenceInt(_accentColorIndexKey),
    );
  }

  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  int get accentColorIndex => _accentColorIndex;
  Color get accentSeed => MoaiAccentColors.seedAt(_accentColorIndex);

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    await _prefs.saveBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setAccentColorIndex(int index) async {
    final next = MoaiAccentColors.clampIndex(index);
    if (_accentColorIndex == next) return;
    _accentColorIndex = next;
    await _prefs.saveInt(_accentColorIndexKey, next);
    notifyListeners();
  }
}
