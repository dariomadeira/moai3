import 'package:flutter/services.dart';

/// Servicio Flutter para interactuar con el módulo nativo de captura de voz del control remoto.
class RemoteVoiceTestService {
  static const MethodChannel _channel =
      MethodChannel('com.infomak.moai.tv/remote_voice');

  static Function()? onPlaybackFinished;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlaybackComplete') {
        onPlaybackFinished?.call();
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
    } catch (_) {}
  }

  /// Inicia la grabación del micrófono utilizando AudioSource.VOICE_RECOGNITION.
  static Future<Map<String, dynamic>> startRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('startRecording');
      return res ?? {'success': false, 'error': 'Respuesta nula'};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Detiene la grabación y devuelve la ruta y tamaño en bytes del archivo .m4a generado.
  static Future<Map<String, dynamic>> stopRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('stopRecording');
      return res ?? {'success': false, 'error': 'Respuesta nula'};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Reproduce la grabación de prueba por los altavoces de la TV.
  static Future<Map<String, dynamic>> playRecording() async {
    try {
      final res =
          await _channel.invokeMapMethod<String, dynamic>('playRecording');
      return res ?? {'success': false, 'error': 'Respuesta nula'};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message};
    }
  }

  /// Detiene la reproducción en curso.
  static Future<void> stopPlayback() async {
    try {
      await _channel.invokeMethod('stopPlayback');
    } catch (_) {}
  }
}
