import 'package:flutter/services.dart';
import 'package:moai3/platform/platform_channels.dart';

/// Dictado con la pantalla de voz del sistema: usa el micrófono del control y
/// la app no necesita el permiso de grabar.
abstract final class VoiceSearchService {
  /// Lo que dijo el usuario; `null` si canceló o no se entendió. Lanza
  /// [PlatformException] si el aparato no tiene reconocimiento de voz.
  static Future<String?> listen() =>
      PlatformChannels.remoteVoice.invokeMethod<String>('recognizeSpeech');
}
