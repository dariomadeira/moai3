import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Cachés en disco de las imágenes de películas. Separadas porque pesan muy
/// distinto: las fotos horizontales (hasta 4096 px) no desplazan a los
/// pósters, y la grilla sola ya supera las 200 imágenes de la caché por
/// defecto.
abstract final class MovieImageCache {
  static final CacheManager posters = CacheManager(
    Config(
      'moai_movie_posters_v1',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 1500,
      fileService: HttpFileService(),
    ),
  );

  /// Fotos horizontales: banner, detalle y tarjetas anchas.
  static final CacheManager photos = CacheManager(
    Config(
      'moai_movie_photos_v1',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 150,
      fileService: HttpFileService(),
    ),
  );

  static const String _defaultClearedPref = 'moai_default_image_cache_cleared';

  /// Borra una sola vez la caché por defecto, que ya nadie usa, para no dejar
  /// ocupado el disco del TV.
  static Future<void> clearDefaultCacheOnce(AppPreferences prefs) async {
    if (prefs.readPreferenceBool(_defaultClearedPref)) return;
    try {
      await DefaultCacheManager().emptyCache();
      await prefs.saveBool(_defaultClearedPref, true);
    } catch (e) {
      debugPrint('[MovieImageCache] No se pudo limpiar la caché vieja: $e');
    }
  }
}
