import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/theme/moai_accent_colors.dart';

/// Provider responsable de la apariencia visual (modo oscuro y color de acento).
class ThemeProvider extends ChangeNotifier {
  /// v2 (2026-11-10): el modo oscuro vuelve con el rediseño y arranca
  /// apagado. La vieja (`dark_mode`) valía `true` por defecto y quedó
  /// guardada así en muchos equipos: no se lee, cada uno lo elige en Ajustes.
  static const String _darkModeKey = 'dark_mode_v2';

  /// v2 (2026-11-09): la lista perdió Esmeralda y Ámbar; el índice de la
  /// vieja (`accent_color_index`) se traduce una vez con
  /// [MoaiAccentColors.legacyIndexMap].
  static const String _accentColorIndexKey = 'accent_color_index_v2';
  static const String _legacyAccentColorIndexKey = 'accent_color_index';
  static const String _autoAccentKey = 'auto_accent_color';

  final AppPreferences _prefs;
  late bool _darkMode;
  late bool _autoAccent;
  late int _accentColorIndex;

  ThemeProvider(this._prefs) {
    _darkMode = _prefs.readPreferenceBool(_darkModeKey);
    _autoAccent = _prefs.readPreferenceBool(_autoAccentKey);
    final savedManualIndex = _readManualIndex();
    if (_autoAccent) {
      _accentColorIndex = Random().nextInt(MoaiAccentColors.seeds.length);
    } else {
      _accentColorIndex = savedManualIndex;
    }
  }

  /// El índice manual guardado; la primera vez lo trae de la lista vieja.
  int _readManualIndex() {
    final saved = _prefs.readOptionalInt(_accentColorIndexKey);
    if (saved != null) return MoaiAccentColors.clampIndex(saved);
    final legacy = _prefs.readOptionalInt(_legacyAccentColorIndexKey);
    if (legacy == null) return 0;
    const map = MoaiAccentColors.legacyIndexMap;
    final next = legacy >= 0 && legacy < map.length ? map[legacy] : 0;
    unawaited(_prefs.saveInt(_accentColorIndexKey, next));
    return next;
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
      _accentColorIndex = _readManualIndex();
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
