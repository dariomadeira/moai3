import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/digests/md5.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';
import 'titan_ranger_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Servicio de sincronización del catálogo de películas y series Moiamov
/// con cifrado nativo Triple DES (3DES) y autenticación automática.
class MoiamovApiService {
  static final MoiamovApiService instance = MoiamovApiService._internal();

  MoiamovApiService._internal();

  /// Último error descriptivo al intentar resolver un stream de reproducción.
  String? lastResolutionError;

  /// Registra una línea de diagnóstico en la consola de depuración.
  static void logLine(String message) {
    debugPrint('📋 [MOIAMOV] $message');
  }

  static String _short(String s, [int n = 180]) =>
      s.length > n ? '${s.substring(0, n)}…' : s;

  /// MAC de dispositivo enviada al portal (se usa para vincular la sesión).
  static const String deviceMac = '00:11:22:33:44:55';

  /// MAC real detectada del dispositivo (se licita con la huella nativa).
  static String _deviceMac = deviceMac;

  static String get defaultBaseUrl => kMoiamovBaseUrl;
  static String get portalKey => kMoiamovPortalKey;
  static String get localDocumentKey => kMoiamovLocalDocKey;
  static String get apkPackage => kMoiamovApkPackage;
  static String get apkVer => kMoiamovApkVer;
  static String get spkgVer => kMoiamovSpkgVer;

  static String get defaultUserId => kMoiamovDefaultUserId;
  static String get defaultUserToken => kMoiamovDefaultUserToken;
  static String get defaultPortalCode => kMoiamovDefaultPortalCode;

  String _currentUserId = defaultUserId;
  String _currentUserToken = defaultUserToken;
  String _currentPortalCode = defaultPortalCode;
  String _currentUserIdentity = '';
  String _currentSnField = '';
  String _currentB29 = '';
  static String _activeSnField = '';

  CatalogResult? _cachedCatalog;
  CatalogResult? get cachedCatalog => _cachedCatalog;

  /// Evita reactivar en bucle (el servidor corta el TLS si se lo bombardea).
  bool _reactivationTried = false;

  bool _syncCancelled = false;
  final Set<HttpClient> _liveClients = {};

  bool get syncCancelled => _syncCancelled;

  /// Permite un nuevo intento de descarga después de un arranque cancelado.
  void beginCatalogSync() {
    _syncCancelled = false;
    _reactivationTried = false;
  }

  /// Cierra las descargas en curso para que el arranque no siga esperando.
  void cancelActiveRequests() {
    _syncCancelled = true;
    for (final client in _liveClients.toList()) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  void _trackClient(HttpClient client) {
    _liveClients.add(client);
  }

  void _releaseClient(HttpClient client) {
    _liveClients.remove(client);
    try {
      client.close();
    } catch (_) {}
  }

  static Uint8List _customBase64Decode(String str) {
    const pem =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final pemMap = List<int>.filled(256, -1);
    for (int i = 0; i < pem.length; i++) {
      pemMap[pem.codeUnitAt(i)] = i;
    }

    final bytes = latin1.encode(str);
    final out = <int>[];
    int idx = 0;
    while (idx < bytes.length) {
      final buf = <int>[];
      while (idx < bytes.length && buf.length < 4) {
        final b = bytes[idx++];
        if (b != 10 && b != 13) {
          buf.add(b);
        }
      }
      if (buf.length == 4) {
        final b0 = pemMap[buf[0]];
        final b1 = pemMap[buf[1]];
        final b2 = pemMap[buf[2]];
        final b3 = pemMap[buf[3]];
        if (buf[2] == 61) {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
        } else if (buf[3] == 61) {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
          out.add(((b1 << 4) & 0xF0) | ((b2 >> 2) & 0x0F));
        } else {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
          out.add(((b1 << 4) & 0xF0) | ((b2 >> 2) & 0x0F));
          out.add(((b2 << 6) & 0xC0) | (b3 & 0x3F));
        }
      }
    }
    return Uint8List.fromList(out);
  }

  static String _toHexString(String str) {
    final sb = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      sb.write(str.codeUnitAt(i).toRadixString(16));
    }
    return sb.toString();
  }

  static String _fromHexString(String hex) {
    final sb = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      final str = hex.substring(i, i + 2);
      sb.writeCharCode(int.parse(str, radix: 16));
    }
    return sb.toString();
  }

  /// Descifra cadenas o documentos cifrados con Triple DES (ECB + PKCS7)
  static String decryptDocument(String hexData, {String? key}) {
    key ??= localDocumentKey;
    final base64Str = _fromHexString(hexData);
    var keyBytes = _customBase64Decode(key);
    if (keyBytes.length > 24) {
      keyBytes = Uint8List.fromList(keyBytes.sublist(0, 24));
    }

    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(DESedeEngine()),
    );
    cipher.init(
      false,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        KeyParameter(keyBytes),
        null,
      ),
    );

    final inputBytes = _customBase64Decode(base64Str);
    final decryptedBytes = cipher.process(inputBytes);
    return utf8.decode(decryptedBytes, allowMalformed: true);
  }

  /// Cifra el payload en texto plano con Triple DES (ECB + PKCS7) y lo convierte a Hex
  /// replicando exactamente fc.b.b de la app oficial.
  static String encryptPayload(Map<String, dynamic> rawMap) {
    final mergedMap = Map<String, dynamic>.from(rawMap);
    // Inyectar metadatos de dispositivo oficiales requeridos por zb.b
    mergedMap.putIfAbsent('loginType', () => '2');
    mergedMap.putIfAbsent('appLanguage', () => 'es');
    mergedMap.putIfAbsent('apkVersion', () => apkVer);
    mergedMap.putIfAbsent('sysVersion', () => spkgVer);
    mergedMap.putIfAbsent('appId', () => apkPackage);
    mergedMap.putIfAbsent('hardwareInfo', () => 'x86_64');
    mergedMap.putIfAbsent('model', () => 'Television');
    mergedMap.putIfAbsent('product', () => 'sdk_google');
    mergedMap.putIfAbsent('abi', () => 'x86_64');
    mergedMap.putIfAbsent('deviceToken', () => '1fb16e34b8dd3831');
    if (_activeSnField.isNotEmpty) {
      mergedMap.putIfAbsent('sn', () => _activeSnField);
    } else {
      mergedMap.putIfAbsent('sn', () => '');
    }
    mergedMap.putIfAbsent('drmId', () => '');
    mergedMap.putIfAbsent('sdkVer', () => 34);

    final plainJson = jsonEncode(mergedMap);

    var keyBytes = _customBase64Decode(portalKey);
    if (keyBytes.length > 24) {
      keyBytes = Uint8List.fromList(keyBytes.sublist(0, 24));
    }

    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(DESedeEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        KeyParameter(keyBytes),
        null,
      ),
    );

    final inputBytes = utf8.encode(plainJson);
    final encryptedBytes = cipher.process(Uint8List.fromList(inputBytes));
    final base64Enc = base64.encode(encryptedBytes);
    return _toHexString(base64Enc);
  }

  String _cleanUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty || url.contains('185.246.208.74')) {
      url = defaultBaseUrl;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  void _setCommonHeaders(HttpClientRequest req) {
    req.headers.set('Content-Type', 'application/json;charset=utf-8');
    req.headers.set('apk', apkPackage);
    req.headers.set('apkVer', apkVer);
    req.headers.set('spkgVer', spkgVer);
    req.headers.set('PORTAL_KEY', portalKey);
    req.headers.set('ProcessResult', 'false');
    req.headers.set(
      'User-Agent',
      'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36',
    );
    if (_currentUserId.isNotEmpty) {
      req.headers.set('userId', _currentUserId);
    }
    if (_currentUserIdentity.isNotEmpty) {
      req.headers.set('userIdentity', _currentUserIdentity);
    }
  }

  /// POST cifrado reutilizable (inyecta headers oficiales y cifra el body).
  Future<String?> _postEncrypted(
    HttpClient client,
    String url,
    Map<String, dynamic> payload,
    Duration timeout,
  ) async {
    try {
      final req = await client.postUrl(Uri.parse(url)).timeout(timeout);
      _setCommonHeaders(req);
      req.write(encryptPayload(payload));
      final resp = await req.close().timeout(timeout);
      final body = await resp.transform(utf8.decoder).join().timeout(timeout);
      if (resp.statusCode != 200) {
        logLine('⚠️ HTTP ${resp.statusCode} en $url');
        return null;
      }
      return body;
    } catch (e) {
      logLine('⚠️ Error HTTP en $url: $e');
      return null;
    }
  }

  static const MethodChannel _deviceChannel = PlatformChannels.device;

  /// Recolecta la huella de dispositivo real (mismo concepto que C1446c0 del
  /// APK) para registrarla en v3/snToken. Sin esto el server no emite token.
  static const Map<String, String> _fallbackFingerprint = {
    'androidId': '0000000000000000',
    'wifiMac': '02:00:00:00:00:00',
    'etheMac': '02:00:00:00:00:00',
    'serialNumber': 'EMULATOR',
    'diskInfo': '',
    'ramSize': '2048MB',
    'romSize': '6144MB',
    'gatewayMac': '02:00:00:00:00:00',
    'cpuId': 'unknown',
    'display': 'unknown',
    'brand': 'unknown',
    'verId': 'unknown',
    'cpuAbi': 'x86_64',
    'hardware': 'unknown',
    'manufacturer': 'unknown',
    'fingerprint': 'unknown',
    'host': 'unknown',
    'device': 'unknown',
    'board': 'unknown',
    'tags': 'unknown',
  };

  static Future<Map<String, String>> _deviceFingerprint() async {
    try {
      final res = await _deviceChannel.invokeMethod<Object>(
        'getDeviceFingerprint',
      );
      if (res is Map && res.isNotEmpty) {
        return res.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (e) {
      logLine('Fingerprint nativo no disponible: $e');
    }
    return Map<String, String>.from(_fallbackFingerprint);
  }

  /// POST /api/portalCore/v3/snToken (flujo guest real del APK: equipo SIN SN,
  /// sin credenciales). Replica el SnTokenBean de la app original y devuelve
  /// el `snToken` que luego exige v8/active. Sin este paso, `active` responde
  /// returnCode 1 "请求参数异常" (parámetros incompletos).
  Future<Map<String, dynamic>?> _fetchSnToken(
    HttpClient client,
    String baseUrl,
    Map<String, String> fp,
    Duration timeout,
  ) async {
    final body = await _postEncrypted(
      client,
      '$baseUrl/api/portalCore/v3/snToken',
      <String, dynamic>{
        'loginType': '2',
        'androidId': fp['androidId'],
        'wifiMac': _deviceMac,
        'etheMac': (fp['etheMac'] ?? '').isEmpty ? _deviceMac : fp['etheMac'],
        'serialNumber': fp['serialNumber'],
        'diskInfo': fp['diskInfo'],
        'ramSize': fp['ramSize'],
        'romSize': fp['romSize'],
        'gatewayMac': (fp['gatewayMac'] ?? '').isEmpty
            ? _deviceMac
            : fp['gatewayMac'],
        'cpuId': fp['cpuId'],
        'display': fp['display'],
        'brand': fp['brand'],
        'verId': fp['verId'],
        'cpuAbi': fp['cpuAbi'],
        'hardware': fp['hardware'],
        'manufacturer': fp['manufacturer'],
        'fingerprint': fp['fingerprint'],
        'host': fp['host'],
        'device': fp['device'],
        'board': fp['board'],
        'tags': fp['tags'],
      },
      timeout,
    );
    if (body == null) return null;
    logLine('v3/snToken resp: ${_short(body)}');
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['returnCode']?.toString() != '0') {
      logLine(
        'snToken rechazado: ${decoded['returnCode']} (${decoded['errorMessage']})',
      );
      return null;
    }
    final data = _decodeData(decoded['data']);
    if (data is! Map<String, dynamic>) {
      logLine(
        'snToken sin data (crudo=${_short(decoded['data']?.toString() ?? 'null')})',
      );
      return null;
    }
    final snToken = data['snToken']?.toString() ?? '';
    final sn = data['sn']?.toString() ?? '';
    final token = snToken.isNotEmpty ? snToken : sn;
    if (token.isEmpty) {
      logLine('snToken sin token en respuesta (isNew=${data['isNew']})');
      return null;
    }
    logLine('✅ snToken obtenido: $token${sn.isNotEmpty ? ' (sn=$sn)' : ''}');
    return <String, dynamic>{...data, '_token': token};
  }

  /// MD5 en hex minúscula (replica AbstractC5097i.m20666a del APK).
  static String _md5Hex(String input) {
    final digest = MD5Digest();
    final bytes = digest.process(Uint8List.fromList(utf8.encode(input)));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toLowerCase();
  }

  /// Cifra un texto con la clave indicada usando 3DES/ECB/PKCS7 y lo devuelve
  /// en hex(base64(cipher)), igual que AbstractC4310b.m18077b del APK.
  static String _encryptWithKey(String plain, String key) {
    var keyBytes = _customBase64Decode(key);
    if (keyBytes.length > 24) {
      keyBytes = Uint8List.fromList(keyBytes.sublist(0, 24));
    }
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      ECBBlockCipher(DESedeEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        KeyParameter(keyBytes),
        null,
      ),
    );
    final enc = cipher.process(Uint8List.fromList(utf8.encode(plain)));
    return _toHexString(base64.encode(enc));
  }

  /// Descifra el campo `data` de una respuesta del portal. El server SIEMPRE
  /// devuelve `data` como hex del payload 3DES (igual que el cliente oficial).
  dynamic _decodeData(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(decryptDocument(data.trim(), key: portalKey));
      } catch (e) {
        logLine('⚠️ No se pudo descifrar data del server: $e');
        return null;
      }
    }
    return data;
  }

  /// Procesa la respuesta de v8/active y actualiza userId/userToken/portalCode.
  bool _applyActiveResult(Map<String, dynamic> actDecoded) {
    final retCode = actDecoded['returnCode']?.toString();
    if (retCode != '0' && retCode != '0000') return false;
    final data = _decodeData(actDecoded['data']);
    if (data is! Map<String, dynamic>) return false;
    if (data['userId'] != null) _currentUserId = data['userId'].toString();
    if (data['userToken'] != null) {
      _currentUserToken = data['userToken'].toString();
    }
    if (data['userIdentity'] != null) {
      _currentUserIdentity = data['userIdentity'].toString();
    } else if (data['identity'] != null) {
      _currentUserIdentity = data['identity'].toString();
    }
    final pcl = data['portalCodeList'];
    if (pcl is List &&
        pcl.isNotEmpty &&
        pcl[0] is Map &&
        pcl[0]['portalCode'] != null) {
      _currentPortalCode = pcl[0]['portalCode'].toString();
    } else if (data['portalCode'] != null) {
      _currentPortalCode = data['portalCode'].toString();
    }
    logLine(
      '✅ Sesión activada: userId=$_currentUserId portal=$_currentPortalCode identity=$_currentUserIdentity mac=$_deviceMac',
    );
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('moiamov_user_id', _currentUserId);
        prefs.setString('moiamov_user_token', _currentUserToken);
        prefs.setString('moiamov_portal_code', _currentPortalCode);
        prefs.setString('moiamov_user_identity', _currentUserIdentity);
        prefs.setString('moiamov_device_mac', _deviceMac);
        prefs.setString('moiamov_sn_field', _currentSnField);
        prefs.setString('moiamov_b29', _currentB29);
      });
    } catch (_) {}
    return true;
  }

  /// Restaura los tokens de sesión guardados en almacenamiento local si existen.
  Future<void> restoreSessionFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('moiamov_user_token');
      if (token != null && token.isNotEmpty) {
        _currentUserToken = token;
        _currentUserId = prefs.getString('moiamov_user_id') ?? _currentUserId;
        _currentPortalCode =
            prefs.getString('moiamov_portal_code') ?? _currentPortalCode;
        _currentUserIdentity = prefs.getString('moiamov_user_identity') ?? '';
        final savedMac = prefs.getString('moiamov_device_mac');
        if (savedMac != null && savedMac.isNotEmpty) {
          _deviceMac = savedMac;
        }
        final savedSn = prefs.getString('moiamov_sn_field');
        if (savedSn != null && savedSn.isNotEmpty) {
          _currentSnField = savedSn;
          _activeSnField = savedSn;
        }
        _currentB29 = prefs.getString('moiamov_b29') ?? '';
        logLine(
          '🔑 Sesión activa restaurada: userId=$_currentUserId portal=$_currentPortalCode mac=$_deviceMac sn=${_currentSnField.isNotEmpty ? "OK" : "vacío"}',
        );
      }

      // Si la MAC sigue siendo la default, consultar fingerprint nativo de inmediato
      if (_deviceMac == deviceMac) {
        final fp = await _deviceFingerprint();
        final realMac =
            (fp['wifiMac'] ?? '').isEmpty ||
                fp['wifiMac'] == '02:00:00:00:00:00'
            ? (fp['etheMac'] ?? deviceMac)
            : (fp['wifiMac'] ?? deviceMac);
        if (realMac.isNotEmpty && realMac != '02:00:00:00:00:00') {
          _deviceMac = realMac;
        }
      }
    } catch (e) {
      logLine('⚠️ Error al restaurar sesión: $e');
    }
  }

  /// Autenticación oficial anónima por dispositivo.
  /// Flujo guest (equipo SIN SN), replicado del APK: v3/snToken -> v8/active.
  /// terminalAuth solo aplica a boxes con SN y NO se usa acá para no saturar al
  /// servidor (menos requests = menos cortes TLS por la VPN).
  Future<bool> activateDeviceSession({
    String? serverUrl,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final fp = await _deviceFingerprint();
    logLine(
      'Dispositivo: androidId=${fp['androidId']} brand=${fp['brand']} device=${fp['device']}',
    );
    _deviceMac =
        (fp['wifiMac'] ?? '').isEmpty || fp['wifiMac'] == '02:00:00:00:00:00'
        ? (fp['etheMac'] ?? deviceMac)
        : (fp['wifiMac'] ?? deviceMac);

    final candidateHosts = <String>{
      serverUrl ?? defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.toList();

    for (final host in candidateHosts) {
      if (_syncCancelled) return false;
      final baseUrl = _cleanUrl(host);
      final ioClient = HttpClient()
        ..badCertificateCallback = ((cert, h, p) => true)
        ..connectionTimeout = timeout;
      _trackClient(ioClient);
      try {
        logLine('Sesión: v3/snToken → $baseUrl');
        final sn = await _fetchSnToken(ioClient, baseUrl, fp, timeout);
        if (sn == null) continue;
        final snToken = sn['_token']?.toString() ?? '';
        if (snToken.isEmpty) continue;

        // Campo `sn` requerido por el envelope (C1446c0.m6748t = KEY_SP_SN):
        // MD5(snToken + salt) en minúscula, calculado por C0132a1 tras v3/snToken.
        final snField = _md5Hex('$snToken$kMoiamovSnSalt');
        _currentSnField = snField;
        _activeSnField = snField;
        final localMac = _deviceMac.replaceAll(':', '');
        final reserve1 = _encryptWithKey(
          localMac.isEmpty ? '000000000000' : localMac,
          kMoiamovDeviceCipherKey,
        );
        final b29 = _encryptWithKey(
          (fp['serialNumber'] ?? '').isEmpty
              ? '000000000000'
              : fp['serialNumber']!,
          kMoiamovDeviceCipherKey,
        );
        _currentB29 = b29;

        logLine('Sesión: v8/active → $baseUrl');
        final actBody = await _postEncrypted(
          ioClient,
          '$baseUrl/api/portalCore/v8/active',
          <String, dynamic>{
            'loginType': '2',
            'snToken': snToken,
            'authVersion': '',
            'authCode': '',
            'preCode': '',
            'macAddr': _deviceMac,
            'reserve1': reserve1,
            'openNum': 0,
            'channel': 'default',
            'matadata': '',
            'signdata': '',
            'sn': snField,
            'cpu': fp['cpuAbi'] ?? 'x86_64',
            'B29': b29,
          },
          timeout,
        );
        await Future.delayed(const Duration(milliseconds: 300));
        if (actBody == null) continue;
        logLine('v8/active resp: ${_short(actBody)}');
        final actDecoded = jsonDecode(actBody);
        if (actDecoded is! Map<String, dynamic>) continue;
        final rc = actDecoded['returnCode']?.toString() ?? '';
        final em = actDecoded['errorMessage']?.toString() ?? '';
        if (rc == 'portal100024' || em.contains('黑名单') || em.contains('区域')) {
          logLine(
            '🚫 La salida de red fue rechazada. Reintentá con otro nodo.',
          );
          lastResolutionError =
              LocaleKeys.movies_error_region.tr();
          return false;
        }
        if (_applyActiveResult(actDecoded)) {
          return true;
        }
        logLine('active rechazado: $rc ($em)');
      } catch (e) {
        logLine('Sesión: excepción en $host: $e');
      } finally {
        _releaseClient(ioClient);
      }
    }
    logLine('⚠️ No se pudo activar sesión en ningún host.');
    return false;
  }

  /// Asegura una sesión activa y autenticada del dispositivo
  Future<bool> ensureSession({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return await activateDeviceSession(timeout: timeout);
  }

  /// Sincroniza y actualiza el catálogo (features, películas o series)
  /// Solo descarga en vivo (`getNextColumns`); lo que baja se guarda en disco.
  /// Si falla devuelve un catálogo vacío: no hay respaldos.
  Future<CatalogResult> syncCatalog({
    String section = 'masnew_movies',
    String? serverUrl,
    String? userToken,
    String? userId,
    String? portalCode,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    serverUrl ??= defaultBaseUrl;
    final sectionLabel = _sectionLabel(section);

    // 1. Descarga en vivo por API directa
    final candidateHosts = <String>{
      serverUrl,
      'https://ftmrmy.jdfey0cd.com',
    }.toList();

    final candidateCodes = <String>[section];

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final endpointUri = Uri.parse('$baseUrl/api/portalCore/getNextColumns');

      for (final code in candidateCodes) {
        if (_syncCancelled) {
          return _emptyCatalog(sectionLabel);
        }
        logLine('getNextColumns $sectionLabel: código "$code" → $host');

        final ioClient = HttpClient()
          ..badCertificateCallback = ((cert, h, p) => true)
          ..connectionTimeout = timeout;
        _trackClient(ioClient);

        try {
          final request = await ioClient.postUrl(endpointUri).timeout(timeout);
          request.headers.set('Content-Type', 'application/json;charset=utf-8');
          request.headers.set('ProcessResult', 'false');
          request.headers.set(
            'User-Agent',
            'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36',
          );
          request.headers.set('apk', apkPackage);
          request.headers.set('apkVer', apkVer);
          request.headers.set('spkgVer', spkgVer);
          request.headers.set('PORTAL_KEY', portalKey);

          final queryData = {
            'userToken': userToken ?? _currentUserToken,
            'userId': userId ?? _currentUserId,
            'portalCode': portalCode ?? _currentPortalCode,
            'pageNum': 1,
            'pageSize': 50,
            'columnCode': code,
            'version': '',
          };

          final encryptedBody = encryptPayload(queryData);
          request.write(encryptedBody);

          final response = await request.close().timeout(timeout);
          final responseBody = await response
              .transform(utf8.decoder)
              .join()
              .timeout(timeout);

          if (response.statusCode != 200) {
            logLine('⚠️ HTTP ${response.statusCode} ($host / $code)');
            continue;
          }

          final decoded = jsonDecode(responseBody);
          if (decoded is! Map<String, dynamic>) continue;
          final returnCode = decoded['returnCode']?.toString();
          final errMsg = decoded['errorMessage'];
          logLine(
            '↳ returnCode=$returnCode${errMsg != null ? ' ($errMsg)' : ''}',
          );

          if (returnCode == '0' ||
              returnCode == '0000' ||
              returnCode == '200') {
            final innerData = _decodeData(decoded['data']);
            List? rawList;
            if (innerData is Map<String, dynamic> &&
                innerData['recommendList'] is List) {
              rawList = innerData['recommendList'];
            } else if (decoded['recommendList'] is List) {
              rawList = decoded['recommendList'];
            }

            if (rawList != null) {
              final list = rawList
                  .whereType<Map<String, dynamic>>()
                  .map(CategoryColumn.fromJson)
                  .where((cat) => cat.movies.isNotEmpty)
                  .toList();

              if (list.isNotEmpty) {
                final total = list.fold(0, (sum, c) => sum + c.movies.length);
                logLine(
                  '✅ EN VIVO: $total títulos en ${list.length} categorías ($sectionLabel)',
                );
                final result = CatalogResult(
                  categories: list,
                  isFromNetwork: true,
                  source: CatalogSource.liveApi,
                  statusMessage:
                      '$sectionLabel ACTUALIZADO EN VIVO ($total títulos en ${list.length} categorías)',
                );
                _cachedCatalog = result;
                await _persistLiveCatalog(section, rawList);
                return result;
              }
              logLine(
                '⚠️ Respuesta OK pero sin títulos ($sectionLabel / $code).',
              );
            }
          } else if (returnCode == 'aaa100028') {
            logLine('⚠️ Sesión no válida (aaa100028) en $host');
            if (!_reactivationTried) {
              _reactivationTried = true;
              logLine('↻ Reactivando dispositivo (una sola vez)...');
              final activated = await activateDeviceSession(
                serverUrl: host,
                timeout: const Duration(seconds: 6),
              );
              if (activated) {
                return await syncCatalog(
                  section: section,
                  serverUrl: host,
                  timeout: timeout,
                );
              }
            }
          }
        } catch (e) {
          logLine('⚠️ Error consultando $host ($code): $e');
        } finally {
          _releaseClient(ioClient);
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    // Sin respaldos: si no bajó en vivo, la sección queda sin actualizar.
    logLine('⚠️ $sectionLabel no se pudo descargar.');
    return _emptyCatalog(sectionLabel);
  }

  static const Set<String> _persistableSections = {
    'masnew_movies',
    'masnew_featured',
    'masnew_series',
  };

  Directory? _catalogDirectoryOverride;

  /// Carpeta de prueba. En la app se usa el directorio privado de soporte.
  @visibleForTesting
  void debugSetCatalogDirectory(Directory? directory) {
    _catalogDirectoryOverride = directory;
  }

  Future<Directory> _catalogDirectory() async {
    final override = _catalogDirectoryOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/catalog');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  Future<void> _persistLiveCatalog(String section, List rawList) async {
    if (!_persistableSections.contains(section)) return;
    try {
      final dir = await _catalogDirectory();
      final file = File('${dir.path}/$section.json');
      final payload = jsonEncode({'recommendList': rawList});
      await file.writeAsString(payload, flush: true);
      logLine('Guardada última descarga de $section.');
    } catch (e) {
      logLine('No se pudo guardar $section: $e');
    }
  }

  static const String _catalogDateKey = 'moiamov_catalog_date';

  /// Fecha del catálogo: se guarda solo cuando bajan las 3 secciones.
  /// Null si todavía no hubo una descarga completa.
  Future<DateTime?> lastSavedCatalogAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_catalogDateKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (e) {
      logLine('No se pudo leer la fecha del catálogo: $e');
      return null;
    }
  }

  Future<void> saveCatalogDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_catalogDateKey, date.toIso8601String());
  }

  /// Secciones que tienen una descarga guardada en disco.
  Future<Set<String>> savedSections() async {
    final saved = <String>{};
    try {
      final dir = await _catalogDirectory();
      for (final section in _persistableSections) {
        final file = File('${dir.path}/$section.json');
        if (file.existsSync() && file.lengthSync() >= 50) saved.add(section);
      }
    } catch (e) {
      logLine('No se pudo revisar el catálogo guardado: $e');
    }
    return saved;
  }

  /// Lee la última descarga en vivo guardada por esta app.
  Future<CatalogResult?> loadPersistedCatalog(String section) async {
    if (!_persistableSections.contains(section)) return null;
    try {
      final dir = await _catalogDirectory();
      final file = File('${dir.path}/$section.json');
      if (!file.existsSync() || file.lengthSync() < 50) return null;

      final decoded = jsonDecode(await file.readAsString());
      final result = _catalogFromRecommendList(
        decoded,
        source: CatalogSource.savedCatalog,
        isFromNetwork: false,
        statusMessage: _savedStatusMessage(section),
      );
      if (result == null) return null;
      logLine(
        'Última descarga guardada: ${result.totalMovies} títulos ($section).',
      );
      _cachedCatalog = result;
      return result;
    } catch (e) {
      logLine('No se pudo leer la copia guardada de $section: $e');
      return null;
    }
  }

  CatalogResult _emptyCatalog(String sectionLabel) {
    return CatalogResult(
      categories: [],
      isFromNetwork: false,
      statusMessage: LocaleKeys.movies_catalog_empty.tr(
        namedArgs: {'section': sectionLabel},
      ),
    );
  }

  String _savedStatusMessage(String section) {
    final sectionLabel = _sectionLabel(section);
    return LocaleKeys.movies_catalog_from_saved.tr(
      namedArgs: {'section': sectionLabel},
    );
  }

  static String _sectionLabel(String section) => switch (section) {
        'masnew_featured' => LocaleKeys.movies_panel_featured_title.tr(),
        'masnew_series' => LocaleKeys.movies_panel_series_title.tr(),
        _ => LocaleKeys.movies_panel_movies_title.tr(),
      };

  CatalogResult? _catalogFromRecommendList(
    Object? decoded, {
    required CatalogSource source,
    required bool isFromNetwork,
    required String statusMessage,
  }) {
    if (decoded is! Map<String, dynamic> || decoded['recommendList'] is! List) {
      return null;
    }
    final list = (decoded['recommendList'] as List)
        .whereType<Map<String, dynamic>>()
        .map(CategoryColumn.fromJson)
        .where((cat) => cat.movies.isNotEmpty)
        .toList();
    if (list.isEmpty) return null;
    return CatalogResult(
      categories: list,
      isFromNetwork: isFromNetwork,
      source: source,
      statusMessage: statusMessage,
    );
  }

  /// Consulta las calidades, audios y subtítulos disponibles de una película (v10).
  Future<VodPlayInfo?> startPlayVOD({
    required String contentId,
    String type = '1',
    int columnId = -1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final candidateHosts = <String>{
      defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.toList();

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final ioClient = HttpClient()
        ..badCertificateCallback = ((cert, h, p) => true)
        ..connectionTimeout = timeout;
      _trackClient(ioClient);

      try {
        final payload = <String, dynamic>{
          'userToken': _currentUserToken,
          'userId': _currentUserId,
          'portalCode': _currentPortalCode,
          'columnId': columnId,
          'contentId': contentId,
          'seriesContentId': '',
          'type': type,
          'startTime': 0,
          'authType': null,
          'episodeNumberList': null,
        };

        logLine('startPlayVOD ($contentId) → $baseUrl');
        final body = await _postEncrypted(
          ioClient,
          '$baseUrl/api/portalCore/v10/startPlayVOD',
          payload,
          timeout,
        );

        if (body == null) continue;
        final decoded = jsonDecode(body);
        if (decoded is! Map<String, dynamic>) continue;

        final returnCode = decoded['returnCode']?.toString();
        if (returnCode == '0' || returnCode == '0000' || returnCode == '200') {
          final data = _decodeData(decoded['data']);
          if (data is Map<String, dynamic>) {
            logLine('📦 startPlayVOD data completa: ${jsonEncode(data)}');
            final info = VodPlayInfo.fromJson(data);
            logLine(
              '✅ startPlayVOD éxito: "${info.name}" (${info.qualities.length} calidades, ${info.subtitles.length} subs)',
            );
            return info;
          }
        } else {
          logLine(
            '⚠️ startPlayVOD returnCode=$returnCode (${decoded['errorMessage']})',
          );
          if (returnCode == 'aaa100028') {
            lastResolutionError =
                LocaleKeys.movies_error_session_expired.tr();
          } else if (decoded['errorMessage'] != null &&
              decoded['errorMessage'].toString().isNotEmpty) {
            lastResolutionError = decoded['errorMessage'].toString();
          }
        }
      } catch (e) {
        logLine('⚠️ Error en startPlayVOD ($host): $e');
      } finally {
        _releaseClient(ioClient);
      }
    }
    return null;
  }

  /// Obtiene la URL de streaming HLS firmada para una pista de video específica (v14/v15).
  Future<String?> getSlbInfo({
    required String mediaContentId,
    String? license,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final localMac = _deviceMac.replaceAll(':', '');
    final reserve1 = _encryptWithKey(
      localMac.isEmpty ? '000000000000' : localMac,
      kMoiamovDeviceCipherKey,
    );

    final candidateHosts = <String>{
      defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.toList();

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final ioClient = HttpClient()
        ..badCertificateCallback = ((cert, h, p) => true)
        ..connectionTimeout = timeout;
      _trackClient(ioClient);

      try {
        logLine(
          'getSlbInfo ($mediaContentId) → $baseUrl (mac: $_deviceMac, sn: ${_currentSnField.isNotEmpty ? "OK" : "vacío"})',
        );
        final candidateLiveCodes = <String>[
          '15406_live',
          'default_live',
          '${_currentPortalCode}_live',
          mediaContentId,
        ];

        for (final liveCode in candidateLiveCodes) {
          for (final typeVal in ['vod', 'merge']) {
            final payload = <String, dynamic>{
              'userToken': _currentUserToken,
              'userId': _currentUserId,
              'hasPay': '0',
              'userIdentity': _currentUserIdentity,
              'portalCode': _currentPortalCode,
              'type': typeVal,
              'appVer': apkVer,
              'lang': 'es',
              'encMediaSupported': 1,
              'liveCodeList': [liveCode],
              'appParams': '',
              'reserve1': reserve1,
              'pipFlag': '0',
            };
            if (_currentSnField.isNotEmpty) {
              payload['sn'] = _currentSnField;
            }

            for (final version in ['v14', 'v15']) {
              final body = await _postEncrypted(
                ioClient,
                '$baseUrl/api/portalCore/$version/getSlbInfo',
                payload,
                timeout,
              );

              if (body == null) continue;
              final decoded = jsonDecode(body);
              if (decoded is! Map<String, dynamic>) continue;

              final returnCode = decoded['returnCode']?.toString();
              if (returnCode == '0' ||
                  returnCode == '0000' ||
                  returnCode == '200') {
                final data = _decodeData(decoded['data']);
                logLine(
                  '📦 getSlbInfo data completa ($version, $typeVal, $liveCode): ${jsonEncode(data)}',
                );
                if (data is Map<String, dynamic> && data['cdn_list'] is List) {
                  final cdnList = (data['cdn_list'] as List)
                      .whereType<Map>()
                      .toList();
                  // Priorizar CDNs con tag="vod"
                  cdnList.sort((a, b) {
                    final aVod = a['tag']?.toString().toLowerCase() == 'vod'
                        ? 0
                        : 1;
                    final bVod = b['tag']?.toString().toLowerCase() == 'vod'
                        ? 0
                        : 1;
                    return aVod.compareTo(bVod);
                  });

                  for (final cdn in cdnList) {
                    if (cdn['url_list'] is List) {
                      for (final u in cdn['url_list'] as List) {
                        if (u is Map && u['url'] != null) {
                          final urlStr = u['url'].toString().trim();
                          // Solo aceptamos URLs completas. `url_list[].url` suele
                          // ser únicamente el query firmado (`link=...&sign_type=...`)
                          // y `main_addr` es un SLB: armar
                          // `http://SLB/{id}.m3u8?{query}` siempre da 403.
                          if (urlStr.startsWith('http://') ||
                              urlStr.startsWith('https://')) {
                            logLine(
                              '✅ getSlbInfo stream URL directa ($version, $typeVal): ${_short(urlStr, 80)}',
                            );
                            return urlStr;
                          }
                        }
                      }
                    }
                  }

                  logLine(
                    '⚠️ getSlbInfo: el CDN solo entregó tokens firmados '
                    '(tag=${cdnList.isNotEmpty ? cdnList.first['tag'] : '-'}); '
                    'se requiere Titan Ranger para resolver el play_url.',
                  );
                }
              } else {
                logLine(
                  '⚠️ getSlbInfo $version ($typeVal, $liveCode) returnCode=$returnCode (${decoded['errorMessage']})',
                );
              }
            }
          }
        }
      } catch (e) {
        logLine('⚠️ Error en getSlbInfo ($host): $e');
      } finally {
        _releaseClient(ioClient);
      }
    }
    return null;
  }

  /// Obtiene la respuesta de datos completa (cdn_list, play_params) de getSlbInfo (v14/v15).
  Future<Map<String, dynamic>?> getSlbInfoRaw({
    required String mediaContentId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final localMac = _deviceMac.replaceAll(':', '');
    final reserve1 = _encryptWithKey(
      localMac.isEmpty ? '000000000000' : localMac,
      kMoiamovDeviceCipherKey,
    );

    final candidateHosts = <String>{
      defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.toList();

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final ioClient = HttpClient()
        ..badCertificateCallback = ((cert, h, p) => true)
        ..connectionTimeout = timeout;
      _trackClient(ioClient);

      try {
        final candidateLiveCodes = <String>[
          '15406_live',
          'default_live',
          '${_currentPortalCode}_live',
          mediaContentId,
        ];

        for (final liveCode in candidateLiveCodes) {
          for (final typeVal in ['vod', 'merge']) {
            final payload = <String, dynamic>{
              'userToken': _currentUserToken,
              'userId': _currentUserId,
              'hasPay': '0',
              'userIdentity': _currentUserIdentity,
              'portalCode': _currentPortalCode,
              'type': typeVal,
              'appVer': apkVer,
              'lang': 'es',
              'encMediaSupported': 1,
              'liveCodeList': [liveCode],
              'appParams': '',
              'reserve1': reserve1,
              'pipFlag': '0',
            };
            if (_currentSnField.isNotEmpty) {
              payload['sn'] = _currentSnField;
            }

            for (final version in ['v14', 'v15']) {
              final body = await _postEncrypted(
                ioClient,
                '$baseUrl/api/portalCore/$version/getSlbInfo',
                payload,
                timeout,
              );

              if (body == null) continue;
              final decoded = jsonDecode(body);
              if (decoded is! Map<String, dynamic>) continue;

              final returnCode = decoded['returnCode']?.toString();
              if (returnCode == '0' ||
                  returnCode == '0000' ||
                  returnCode == '200') {
                final data = _decodeData(decoded['data']);
                if (data is Map<String, dynamic>) {
                  return data;
                }
              }
            }
          }
        }
      } catch (e) {
        logLine('⚠️ Error en getSlbInfoRaw ($host): $e');
      } finally {
        _releaseClient(ioClient);
      }
    }
    return null;
  }

  /// Resuelve la URL y metadatos de reproducción listos para el reproductor nativo.
  /// Implementa las reglas del PLAN DE IMPLEMENTACIÓN:
  /// - Jerarquía estricta de subtítulos en español (Latino > Neutro > España)
  /// - Audio en español prioritario
  /// - Calidad según preferencia (1080p / 720p)
  Future<ResolvedPlayStream?> resolveMovieStream({
    required MovieItem movie,
    String preferredQuality = 'max',
    Duration timeout = const Duration(seconds: 14),
  }) async {
    lastResolutionError = null;
    logLine(
      '🎬 Iniciando resolución de stream para: "${movie.name}" (ID: ${movie.contentId})',
    );

    // Restaurar tokens de sesión activos si existen en almacenamiento
    await restoreSessionFromStorage();

    // Si no teníamos snField guardado de una sesión previa, vincularlo sin VPN
    if (_currentSnField.isEmpty) {
      logLine('↻ Obteniendo snToken para asociar dispositivo...');
      final fp = await _deviceFingerprint();
      final ioClient = HttpClient()
        ..badCertificateCallback = ((c, h, p) => true);
      _trackClient(ioClient);
      try {
        final sn = await _fetchSnToken(
          ioClient,
          defaultBaseUrl,
          fp,
          const Duration(seconds: 4),
        );
        if (sn != null && sn['_token'] != null) {
          final snToken = sn['_token'].toString();
          _currentSnField = _md5Hex('$snToken$kMoiamovSnSalt');
          _activeSnField = _currentSnField;
          final prefs = await SharedPreferences.getInstance();
          unawaited(prefs.setString('moiamov_sn_field', _currentSnField));
          unawaited(prefs.setString('moiamov_device_mac', _deviceMac));
          logLine(
            '✅ snField vinculado con MAC ($_deviceMac): ${_short(_currentSnField, 16)}',
          );
        }
      } catch (e) {
        logLine('⚠️ Error obteniendo snToken: $e');
      } finally {
        _releaseClient(ioClient);
      }
    }

    // 1. startPlayVOD
    var playInfo = await startPlayVOD(
      contentId: movie.contentId,
      timeout: timeout,
    );

    // Si falló por sesión no inicializada o expirada, intentamos reactivar una sola vez
    if (playInfo == null || playInfo.qualities.isEmpty) {
      logLine('↻ Intentando reactivación de sesión para VOD...');
      final activated = await activateDeviceSession(
        timeout: const Duration(seconds: 6),
      );
      if (activated) {
        playInfo = await startPlayVOD(
          contentId: movie.contentId,
          timeout: timeout,
        );
      }
    }

    if (playInfo == null || playInfo.qualities.isEmpty) {
      logLine(
        '❌ No se encontraron calidades de reproducción para "${movie.name}"',
      );
      lastResolutionError ??=
          LocaleKeys.movies_error_no_play_options.tr();
      return null;
    }

    // 2. Selección de Calidad (PLAN §3.Paso 2.C)
    VodQualityOption selectedQuality;
    if (preferredQuality == '720p') {
      selectedQuality = playInfo.qualities.firstWhere(
        (q) => q.quality.toUpperCase().contains('720'),
        orElse: () => playInfo!.qualities.first,
      );
    } else {
      selectedQuality = playInfo.qualities.firstWhere(
        (q) =>
            q.quality.toUpperCase().contains('1080') ||
            q.quality.toUpperCase().contains('4K'),
        orElse: () => playInfo!.qualities.first,
      );
    }

    // 3. Selección de Audio (PLAN §3.Paso 2.B)
    final selectedSource = selectedQuality.bestAudioSource;
    if (selectedSource == null) {
      logLine(
        '❌ La calidad ${selectedQuality.quality} no tiene pistas de audio válidas',
      );
      lastResolutionError ??=
          LocaleKeys.movies_error_no_audio.tr();
      return null;
    }

    // 4. Selección de Subtítulos (PLAN §3.Paso 2.A)
    final bestSub = playInfo.bestSpanishSubtitle;
    logLine(
      '🔊 Pista elegida: ${selectedQuality.quality} - ${selectedSource.audioInfo} (Media ID: ${selectedSource.mediaContentId})',
    );
    if (bestSub != null) {
      logLine(
        '💬 Subtítulo en español elegido: "${bestSub.name}" (${bestSub.language}) [URL: ${bestSub.url}]',
      );
    }

    // 5. Resolución con Titan Ranger (Alternativa B) o getSlbInfo
    String? streamUrl = selectedSource.directUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      logLine(
        '✅ URL directa encontrada en startPlayVOD: ${_short(streamUrl, 80)}',
      );
    } else {
      // Intento A: Titan Ranger con libranger-jni.so en Android
      if (TitanRangerService.isSupported) {
        logLine(
          '🛡️ [Titan Ranger] Iniciando resolución con libranger-jni.so...',
        );
        try {
          final slbData = await getSlbInfoRaw(
            mediaContentId: selectedSource.mediaContentId,
            timeout: timeout,
          );

          if (slbData != null && slbData['cdn_list'] is List) {
            final cdnList = slbData['cdn_list'] as List;
            final entries = TitanRangerService.mapSlbEntries(cdnList);
            final readyEntries = entries
                .where(
                  (e) =>
                      (e['tag'] as String).isNotEmpty &&
                      (e['sign_type'] as String).isNotEmpty,
                )
                .length;

            await TitanRangerService.init();

            // `android_id` real (Settings.System). El snField NO es el android_id.
            final androidId = await TitanRangerService.getAndroidId();
            final rawPlayParams = slbData['play_params'];
            final playParams = rawPlayParams is String
                ? rawPlayParams
                : (rawPlayParams == null ? '' : jsonEncode(rawPlayParams));
            final effectivePortalKey = portalKey.isNotEmpty
                ? portalKey
                : '2b494e53756c664c2f44465245733572';

            logLine(
              '🛡️ [Titan Ranger] ${entries.length} entries ($readyEntries con link/sign_type), '
              'androidId=${androidId.isNotEmpty ? "OK" : "vacío"}, portalKey=${portalKey.isNotEmpty ? "OK" : "default"}',
            );

            await TitanRangerService.setEnv(
              app: apkPackage.isNotEmpty ? apkPackage : 'com.android.msandroid',
              appVer: apkVer.isNotEmpty ? apkVer : '50503',
              userId: _currentUserId,
              devId: _deviceMac.isNotEmpty ? _deviceMac : '02:00:00:00:00:00',
              communicationKey: effectivePortalKey,
              params: playParams,
              androidId: androidId,
            );

            await TitanRangerService.setEntries(entries);
            // Deja que Ranger procese SetEntries antes de iniciar PrepareProgram.
            // La app oficial encola ambas llamadas en el mismo handler nativo.
            await Future<void>.delayed(const Duration(milliseconds: 400));

            final programPayload = {
              'name': movie.contentId,
              'buss': 'vod',
              'title': movie.name,
              'episode': '1',
              'from': 'detail',
              'cause': 'user',
              'media': selectedSource.mediaContentId,
              'medias': [
                {
                  'name': selectedSource.mediaContentId,
                  'license': selectedSource.license ?? '',
                  'lang': selectedSource.audioInfo,
                  'quality': selectedQuality.quality,
                  'vcodec': selectedSource.encodeFormat ?? 'h265',
                  'format':
                      selectedSource.videoFormat ??
                      selectedSource.videoType ??
                      'ts',
                },
              ],
              'start': 0,
            };

            logLine(
              '🛡️ [Titan Ranger] Despachando PrepareProgram para: "${movie.name}"...',
            );
            final statusResult = await TitanRangerService.prepareProgram(
              // La app oficial pasa program.getName() (ID del programa) como
              // "name" y program.getBuss() ("vod") como "extra".
              name: programPayload['name']!.toString(),
              program: programPayload,
              extra: 'vod',
            );

            if (statusResult != null && statusResult['play_url'] != null) {
              final resolvedPlayUrl = statusResult['play_url']
                  .toString()
                  .trim();
              if (resolvedPlayUrl.startsWith('mem://') ||
                  resolvedPlayUrl.startsWith('ijkhttphook:')) {
                // Ranger resolvió, pero ese esquema requiere el proxy/datasource
                // nativo de IJK (servidor /playinfo + titan_port), no ExoPlayer.
                logLine(
                  '⚠️ [Titan Ranger] play_url con esquema no reproducible por ExoPlayer: $resolvedPlayUrl',
                );
                lastResolutionError =
                    LocaleKeys.movies_error_internal_stream.tr(
                      namedArgs: {'scheme': resolvedPlayUrl.split(':').first},
                    );
              } else if (resolvedPlayUrl.isNotEmpty) {
                logLine(
                  '🎉 [Titan Ranger] Stream URL resuelta por libranger-jni: $resolvedPlayUrl',
                );
                streamUrl = resolvedPlayUrl;
              }
            } else {
              logLine(
                '⚠️ [Titan Ranger] No se obtuvo play_url nativo de Ranger',
              );
            }
          }
        } catch (e) {
          logLine('⚠️ [Titan Ranger] Excepción durante resolución nativa: $e');
        }
      }

      // Intento B (Fallback): getSlbInfo tradicional
      if (streamUrl == null || streamUrl.isEmpty) {
        streamUrl = await getSlbInfo(
          mediaContentId: selectedSource.mediaContentId,
          license: selectedSource.license,
          timeout: timeout,
        );
      }
    }

    if (streamUrl == null) {
      logLine('❌ No se pudo obtener la URL de streaming');
      lastResolutionError ??=
          LocaleKeys.movies_error_unresolved_stream.tr();
      return null;
    }

    return ResolvedPlayStream(
      streamUrl: streamUrl,
      quality: selectedQuality.quality,
      audioInfo: selectedSource.audioInfo,
      subtitleUrl: bestSub?.url,
      subtitleName: bestSub?.name,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36',
        'PORTAL_KEY': portalKey,
        'apk': apkPackage,
        'apkVer': apkVer,
        'spkgVer': spkgVer,
        if (_currentUserId.isNotEmpty) 'userId': _currentUserId,
        if (_currentUserIdentity.isNotEmpty)
          'userIdentity': _currentUserIdentity,
      },
    );
  }
}
