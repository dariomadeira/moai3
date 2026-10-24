import 'package:flutter/foundation.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Micrófono del control remoto y reproducción de mensajes de voz (Miremos Juntos).
/// Lo usan el coordinador de voz y el diálogo de prueba de audio.
class VoiceAudioService {
  static const MethodChannel _channel =
      PlatformChannels.remoteVoice;

  static final List<void Function()> _playbackListeners = [];

  static void addPlaybackListener(void Function() listener) {
    _playbackListeners.add(listener);
  }

  static void removePlaybackListener(void Function() listener) {
    _playbackListeners.remove(listener);
  }

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlaybackComplete') {
        for (final l in List<void Function()>.from(_playbackListeners)) {
          try {
            l();
          } catch (e) {
            debugPrint('[VoiceAudioService] $e');
          }
        }
      }
    });
  }

  /// Consulta qué dispositivos de entrada de audio detecta el sistema Android TV.
  static Future<Map<String, dynamic>> checkHardware() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('checkHardware');
      return res ?? {};
    } on PlatformException catch (e) {
      return {'error': e.message};
    }
  }

  /// Verifica si la aplicación tiene concedido el permiso RECORD_AUDIO.
  static Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Solicita el permiso RECORD_AUDIO en tiempo de ejecución.
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('[VoiceAudioService] $e');
    }
  }

  /// Inicia la grabación del micrófono utilizando AudioSource.VOICE_RECOGNITION.
  static Future<Map<String, dynamic>> startRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('startRecording');
      return res ?? {'success': false, 'error': LocaleKeys.mic_error_null_response.tr()};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Detiene la grabación y devuelve la ruta y tamaño en bytes del archivo .m4a generado.
  static Future<Map<String, dynamic>> stopRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('stopRecording');
      return res ?? {'success': false, 'error': LocaleKeys.mic_error_null_response.tr()};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Reproduce la grabación de prueba por los altavoces de la TV.
  static Future<Map<String, dynamic>> playRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('playRecording');
      return res ?? {'success': false, 'error': LocaleKeys.mic_error_null_response.tr()};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Reproduce un archivo o URL de audio por los altavoces de la TV con LoudnessEnhancer (+18 dB).
  static Future<Map<String, dynamic>> playAudio(String source) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'playAudio',
        {'source': source},
      );
      return res ?? {'success': false, 'error': LocaleKeys.mic_error_null_response.tr()};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Detiene la reproducción en curso.
  static Future<void> stopPlayback() async {
    try {
      await _channel.invokeMethod('stopPlayback');
    } catch (e) {
      debugPrint('[VoiceAudioService] $e');
    }
  }
}
