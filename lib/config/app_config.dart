import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Valor crudo leído del `.env` al arrancar.
  static String? debugModeEnvRaw;

  /// Solo para tests unitarios.
  static bool? debugModeOverride;

  /// Valor crudo de TV_MODE leído del `.env` al arrancar.
  static String? tvModeEnvRaw;

  /// Solo para tests unitarios.
  static bool? tvModeOverride;

  static bool get debugMode {
    if (debugModeOverride != null) return debugModeOverride!;
    const fromDefine = String.fromEnvironment('DEBUG_MODE');
    if (fromDefine.isNotEmpty) {
      return _parseBool(fromDefine);
    }
    return _parseBool(debugModeEnvRaw);
  }

  static bool get tvMode {
    if (tvModeOverride != null) return tvModeOverride!;
    const fromDefine = String.fromEnvironment('TV_MODE');
    if (fromDefine.isNotEmpty) {
      return _parseBool(fromDefine);
    }
    return _parseBool(tvModeEnvRaw);
  }

  static bool _parseBool(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static Future<void> initialize() async {
    debugModeEnvRaw = dotenv.env['DEBUG_MODE'];
    tvModeEnvRaw = dotenv.env['TV_MODE'];
  }
}

