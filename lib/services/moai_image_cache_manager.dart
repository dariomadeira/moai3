import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Gestor de caché persistente optimizado para logos de canales de TV.
/// 
/// Características:
/// - Capacidad para más de 3.000 imágenes (cubre catálogos enteros sin purgas tempranas).
/// - Periodo de expiración extendido (180 días) para evitar descargas repetitivas.
/// - Base de datos SQLite dedicada para aislar los logos de otros recursos temporales.
class MoaiImageCacheManager {
  static const String key = 'moai_channel_logos_v3';
  static const String _legacyKey = 'moai_channel_logos_v2';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 3000,
      fileService: HttpFileService(),
    ),
  );

  static const String _legacyClearedPref = 'moai_channel_logos_v2_cleared';

  /// Borra una sola vez la caché v2 (logos deformados). TODO(SPEC-50 §1.7):
  /// quitar en la release siguiente a la que la incluye.
  static Future<void> clearLegacyCacheOnce(AppPreferences prefs) async {
    if (prefs.readPreferenceBool(_legacyClearedPref)) return;
    try {
      await CacheManager(Config(_legacyKey)).emptyCache();
      await prefs.saveBool(_legacyClearedPref, true);
    } catch (e) {
      debugPrint('[MoaiImageCacheManager] No se pudo limpiar la caché v2: $e');
    }
  }

  /// Genera una clave de caché limpia para evitar que parámetros de consulta dinámicos
  /// (como ?cb=... o ?timestamp=...) provoquen descargas duplicadas.
  static String cleanCacheKey(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.queryParameters.isEmpty) return url;
      // Mantener origen y ruta sin query volátiles
      return '${uri.scheme}://${uri.host}${uri.path}';
    } catch (_) {
      return url;
    }
  }
}
