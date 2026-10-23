import 'dart:io';
import 'package:flutter/services.dart';

/// Servicio puente con la biblioteca nativa libranger-jni.so (Titan Ranger).
/// Usado para resolver la autenticación y balanceo de streams VOD/Live (Alternativa B).
class TitanRangerService {
  static const MethodChannel _channel = MethodChannel(
    'com.infomak.moai.tv/titan_ranger',
  );

  static bool _initialized = false;
  static Future<bool>? _initFuture;

  /// Verifica si el entorno soporta la biblioteca nativa (Android).
  static bool get isSupported => Platform.isAndroid;

  /// Inicializa la biblioteca nativa libranger-jni con la ruta de trabajo interna.
  static Future<bool> init({String? workPath}) {
    if (!isSupported) return Future<bool>.value(false);
    if (_initialized) return Future<bool>.value(true);
    return _initFuture ??= _initialize(workPath);
  }

  static Future<bool> _initialize(String? workPath) async {
    try {
      final args = <String, dynamic>{};
      if (workPath != null) {
        args['workPath'] = workPath;
      }
      final res = await _channel.invokeMethod<bool>('init', args);
      if (res == false) return false;

      // `Init` responde err:0 antes de que Ranger termine de inicializarse
      // (el log nativo "ranger has initialized successfully" aparece después).
      // Si se envían SetEnv/SetEntries/PrepareProgram en ese intervalo, Ranger
      // los descarta y nunca emite OnPrepareEvent -> timeout sin play_url.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      _initialized = true;
      return true;
    } catch (e) {
      return false;
    } finally {
      _initFuture = null;
    }
  }

  /// Configura el entorno de ejecución en Ranger (SetEnv).
  static Future<bool> setEnv({
    String app = 'com.android.msandroid',
    String appVer = '50503',
    required String userId,
    required String devId,
    String communicationKey = '2b494e53756c664c2f44465245733572',
    String params = '',
    String androidId = '',
    int titanPort = -1,
  }) async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setEnv', {
        'env': {
          'app': app,
          'app_ver': appVer,
          'user_id': userId,
          'dev_id': devId,
          'communication_key': communicationKey,
          'params': params,
          'android_id': androidId,
          'titan_port': titanPort,
        },
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Envía los nodos SLB/CDN mapeados desde getSlbInfo (SetEntries).
  static Future<bool> setEntries(List<Map<String, dynamic>> entries) async {
    if (!isSupported) return false;
    try {
      final res = await _channel.invokeMethod<bool>('setEntries', {
        'entries': entries,
      });
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Solicita a Ranger resolver y preparar el stream del programa VOD (PrepareProgram).
  /// Espera asíncronamente el callback nativo `media_prepared` con `play_url`.
  static Future<Map<String, dynamic>?> prepareProgram({
    int instanceId = 0,
    String name = 'vod',
    required Map<String, dynamic> program,
    String extra = '',
  }) async {
    if (!isSupported) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'prepareProgram',
        {
          'instanceId': instanceId,
          'name': name,
          'program': program,
          'extra': extra,
        },
      );
      return res;
    } catch (e) {
      return null;
    }
  }

  /// Detiene la sesión activa de reproducción en Ranger.
  static Future<void> stopProgram({
    int instanceId = 1,
    String name = 'vod',
  }) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('stopProgram', {
        'instanceId': instanceId,
        'name': name,
      });
    } catch (_) {}
  }

  /// Lee el ANDROID_ID real del dispositivo (Settings.System "android_id").
  /// La app oficial lo usa en `Env.android_id`; nunca debe enviarse el snField.
  static Future<String> getAndroidId() async {
    if (!isSupported) return '';
    try {
      final res = await _channel.invokeMethod<String>('getAndroidId');
      return (res ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// Extrae un campo de un query string suelto, por ejemplo
  /// `session_id=...&link=icdn&sign_type=cs&...`.
  ///
  /// No se puede usar `Uri.parse` aquí: `url_list[].url` NO es una URL, es
  /// solo la cadena de parámetros firmados (sin `?`). La app oficial hace
  /// exactamente esta búsqueda de texto en `C7602p0.m29234b`.
  static String _queryField(String raw, String field) {
    if (raw.isEmpty) return '';
    final marker = '$field=';
    final start = raw.indexOf(marker);
    if (start < 0) return '';
    final valueStart = start + marker.length;
    final end = raw.indexOf('&', valueStart);
    final value = end < 0
        ? raw.substring(valueStart)
        : raw.substring(valueStart, end);
    return value.trim();
  }

  /// Transforma la lista `cdn_list` de `getSlbInfo` al formato `Entry` de Ranger.
  static List<Map<String, dynamic>> mapSlbEntries(List<dynamic> cdnList) {
    final entries = <Map<String, dynamic>>[];
    final total = cdnList.length;

    for (final item in cdnList) {
      if (item is! Map) continue;
      final cdn = Map<String, dynamic>.from(item);

      final auths = <String>[];
      if (cdn['url_list'] is List) {
        for (final u in cdn['url_list'] as List) {
          if (u is Map && u['url'] != null) {
            auths.add(u['url'].toString());
          }
        }
      }

      final firstUrl = auths.isNotEmpty ? auths.first : '';
      // `tag` (link) y `sign_type` son imprescindibles para que Ranger firme
      // la petición al SLB. Sin ellos no devuelve `play_url`.
      final linkParam = _queryField(firstUrl, 'link');
      final signTypeParam = _queryField(firstUrl, 'sign_type');

      final cdnType = cdn['cdn_type']?.toString() ?? '';
      final redirect = cdnType == '1' ? 'slb' : '';

      final serialNumber =
          int.tryParse(cdn['serial_number']?.toString() ?? '1') ?? 1;
      final priority = total - serialNumber;

      entries.add({
        'name': cdn['cdn_id_mark']?.toString() ?? '',
        'buss': cdn['tag']?.toString() ?? 'free',
        'strategy': cdn['rule_id_mark']?.toString() ?? '',
        'main_addr': cdn['main_addr']?.toString() ?? '',
        'main_addr_code': cdn['main_addr_mark']?.toString() ?? '',
        'spare_addr': cdn['spared_addr']?.toString() ?? '',
        'spare_addr_code': cdn['spared_addr_mark']?.toString() ?? '',
        'redirect': redirect,
        'tag': linkParam,
        'sign_type': signTypeParam,
        'priority': priority,
        'enable': 1,
        'auths': auths,
        'gslb_params': cdn['group_id_mark']?.toString() ?? '',
      });
    }

    return entries;
  }
}
