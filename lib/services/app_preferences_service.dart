import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper delgado sobre [SharedPreferences] (sin encriptación).
class AppPreferences {
  AppPreferences._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppPreferences> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences._(prefs);
  }

  Future<void> resetAll() => _prefs.clear();

  Future<void> removePreference(String key) => _prefs.remove(key);

  String readPreferenceString(String key) => _prefs.getString(key) ?? '';

  /// `null` si la clave no existe o el valor está vacío.
  String? readOptionalString(String key) {
    final value = _prefs.getString(key);
    if (value == null || value.isEmpty) return null;
    return value;
  }

  Future<void> saveString(String key, String value) =>
      _prefs.setString(key, value);

  bool readPreferenceBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  /// `null` si la clave no existe (distinto de `false` guardado).
  bool? readOptionalBool(String key) => _prefs.getBool(key);

  Future<void> saveBool(String key, bool value) => _prefs.setBool(key, value);

  double readPreferenceDouble(String key, {double defaultValue = 0}) =>
      _prefs.getDouble(key) ?? defaultValue;

  Future<void> saveDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  Future<void> saveStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  List<String> readStringList(String key) =>
      _prefs.getStringList(key) ?? const [];

  int readPreferenceInt(String key) => _prefs.getInt(key) ?? 0;

  Future<void> saveInt(String key, int value) => _prefs.setInt(key, value);
}

