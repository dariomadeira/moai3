import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moai3/platform/platform_channels.dart';

/// Abre videos en la app de YouTube del TV (`openYoutube` en `MainActivity`).
abstract final class YoutubeLauncher {
  /// Abre [videoId]; `false` si ninguna app lo pudo abrir. Nunca falla.
  static Future<bool> open(String videoId) async {
    try {
      final opened = await PlatformChannels.device.invokeMethod<bool>(
        'openYoutube',
        {'videoId': videoId},
      );
      return opened ?? false;
    } on PlatformException catch (e) {
      debugPrint('⚠️ [YouTube] No se pudo abrir $videoId: ${e.message}');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
