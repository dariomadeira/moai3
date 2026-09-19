import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Gestor de caché persistente optimizado para logos de canales de TV.
/// 
/// Características:
/// - Capacidad para más de 3.000 imágenes (cubre catálogos enteros sin purgas tempranas).
/// - Periodo de expiración extendido (180 días) para evitar descargas repetitivas.
/// - Base de datos SQLite dedicada para aislar los logos de otros recursos temporales.
class MoaiImageCacheManager {
  static const String key = 'moai_channel_logos';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 180),
      maxNrOfCacheObjects: 3000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

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
