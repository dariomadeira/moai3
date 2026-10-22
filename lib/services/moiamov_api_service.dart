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
    const pem = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
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
    cipher.init(false, PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
      KeyParameter(keyBytes),
      null,
    ));

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
    cipher.init(true, PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
      KeyParameter(keyBytes),
      null,
    ));

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
    req.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36');
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

  static const MethodChannel _deviceChannel =
      MethodChannel('com.infomak.moai.tv/device');

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
      final res = await _deviceChannel.invokeMethod<Object>('getDeviceFingerprint');
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
        'gatewayMac': (fp['gatewayMac'] ?? '').isEmpty ? _deviceMac : fp['gatewayMac'],
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
      logLine('snToken rechazado: ${decoded['returnCode']} (${decoded['errorMessage']})');
      return null;
    }
    final data = _decodeData(decoded['data']);
    if (data is! Map<String, dynamic>) {
      logLine('snToken sin data (crudo=${_short(decoded['data']?.toString() ?? 'null')})');
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
    cipher.init(true, PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
      KeyParameter(keyBytes),
      null,
    ));
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
    if (data['userToken'] != null) _currentUserToken = data['userToken'].toString();
    if (data['userIdentity'] != null) {
      _currentUserIdentity = data['userIdentity'].toString();
    } else if (data['identity'] != null) {
      _currentUserIdentity = data['identity'].toString();
    }
    final pcl = data['portalCodeList'];
    if (pcl is List && pcl.isNotEmpty && pcl[0] is Map && pcl[0]['portalCode'] != null) {
      _currentPortalCode = pcl[0]['portalCode'].toString();
    } else if (data['portalCode'] != null) {
      _currentPortalCode = data['portalCode'].toString();
    }
    logLine('✅ Sesión activada: userId=$_currentUserId portal=$_currentPortalCode identity=$_currentUserIdentity mac=$_deviceMac');
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
        _currentPortalCode = prefs.getString('moiamov_portal_code') ?? _currentPortalCode;
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
        logLine('🔑 Sesión activa restaurada: userId=$_currentUserId portal=$_currentPortalCode mac=$_deviceMac sn=${_currentSnField.isNotEmpty ? "OK" : "vacío"}');
      }

      // Si la MAC sigue siendo la default, consultar fingerprint nativo de inmediato
      if (_deviceMac == deviceMac) {
        final fp = await _deviceFingerprint();
        final realMac = (fp['wifiMac'] ?? '').isEmpty || fp['wifiMac'] == '02:00:00:00:00:00'
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
    logLine('Dispositivo: androidId=${fp['androidId']} brand=${fp['brand']} device=${fp['device']}');
    _deviceMac = (fp['wifiMac'] ?? '').isEmpty || fp['wifiMac'] == '02:00:00:00:00:00'
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
            kMoiamovDeviceCipherKey);
        final b29 = _encryptWithKey(
            (fp['serialNumber'] ?? '').isEmpty ? '000000000000' : fp['serialNumber']!,
            kMoiamovDeviceCipherKey);
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
          logLine('🚫 La salida de red fue rechazada. Reintentá con otro nodo.');
          lastResolutionError = 'Región no permitida por el servidor. Conecta el túnel seguro.';
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

  /// Intenta cargar el catálogo desde los documentos locales del almacenamiento del TV.
  CatalogResult? _loadFromLocalDeviceDocument(String section) {
    try {
      final sectionLabel = section == 'masnew_featured'
          ? 'Destacados'
          : (section == 'masnew_series' ? 'Series' : 'Películas');

      final candidatePaths = [
        '/sdcard/Android/data/$kMoiamovDocPackage/files/Documents/$section;1',
        '/storage/emulated/0/Android/data/$kMoiamovDocPackage/files/Documents/$section;1',
      ];

      for (final p in candidatePaths) {
        final f = File(p);
        if (f.existsSync() && f.lengthSync() > 100) {
          final rawHex = f.readAsStringSync().trim();
          final decryptedJson = decryptDocument(rawHex, key: localDocumentKey);
          final decoded = jsonDecode(decryptedJson);

          if (decoded is Map<String, dynamic> && decoded['recommendList'] is List) {
            final list = (decoded['recommendList'] as List)
                .whereType<Map<String, dynamic>>()
                .map((e) => CategoryColumn.fromJson(e))
                .where((cat) => cat.movies.isNotEmpty)
                .toList();

            if (list.isNotEmpty) {
              final total = list.fold(0, (sum, c) => sum + c.movies.length);
              logLine('⚡ Documento local: $total títulos ($p)');
              final result = CatalogResult(
                categories: list,
                isFromNetwork: true,
                source: CatalogSource.localDocument,
                statusMessage: '$sectionLabel desde cache local del TV ($total títulos en ${list.length} categorías)',
              );
              _cachedCatalog = result;
              return result;
            }
          }
        }
      }
    } catch (e) {
      logLine('⚠️ Error leyendo cache local: $e');
    }
    return null;
  }

  /// Asegura una sesión activa y autenticada del dispositivo
  Future<bool> ensureSession({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return await activateDeviceSession(timeout: timeout);
  }

  /// Sincroniza y actualiza el catálogo (features, películas o series)
  /// Prioridad 1: Descarga en vivo por API directa (login + getNextColumns)
  /// Prioridad 2: Almacenamiento local del dispositivo
  /// Prioridad 3: Respaldo empaquetado en assets
  Future<CatalogResult> syncCatalog({
    String section = 'masnew_movies',
    String? serverUrl,
    String? userToken,
    String? userId,
    String? portalCode,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    serverUrl ??= defaultBaseUrl;
    final sectionLabel = section == 'masnew_featured'
        ? 'Destacados'
        : (section == 'masnew_series' ? 'Series' : 'Películas');

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
          request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36');
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
          final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);

          if (response.statusCode != 200) {
            logLine('⚠️ HTTP ${response.statusCode} ($host / $code)');
            continue;
          }

          final decoded = jsonDecode(responseBody);
          if (decoded is! Map<String, dynamic>) continue;
          final returnCode = decoded['returnCode']?.toString();
          final errMsg = decoded['errorMessage'];
          logLine('↳ returnCode=$returnCode${errMsg != null ? ' ($errMsg)' : ''}');

          if (returnCode == '0' || returnCode == '0000' || returnCode == '200') {
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
                  .map((e) => CategoryColumn.fromJson(e))
                  .where((cat) => cat.movies.isNotEmpty)
                  .toList();

              if (list.isNotEmpty) {
                final total = list.fold(0, (sum, c) => sum + c.movies.length);
                logLine('✅ EN VIVO: $total títulos en ${list.length} categorías ($sectionLabel)');
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
              logLine('⚠️ Respuesta OK pero sin títulos ($sectionLabel / $code).');
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
                return await syncCatalog(section: section, serverUrl: host, timeout: timeout);
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

    if (_syncCancelled) {
      return _emptyCatalog(sectionLabel);
    }

    // 2. Última descarga que esta app guardó
    logLine('ℹ️ API en vivo no devolvió $sectionLabel. Probando la última copia guardada...');
    final saved = await loadPersistedCatalog(section);
    if (saved != null) {
      return saved;
    }

    // 3. Almacenamiento local del dispositivo
    logLine('Probando cache local del TV...');
    final localLive = _loadFromLocalDeviceDocument(section);
    if (localLive != null) {
      return localLive;
    }

    // 4. Respaldo empaquetado. No se guarda: no debe pisar una descarga anterior.
    logLine('📦 Usando respaldo HARDCODEADO para $sectionLabel.');
    return loadFallbackCatalog(section: section);
  }

  /// Sincroniza todas las secciones clave al abrir la app (Películas, Destacados y Series)
  Future<void> syncAll({Duration timeout = const Duration(seconds: 10)}) async {
    debugPrint('🚀 [SYNC ALL] Iniciando sincronización integral de catálogo...');
    await syncCatalog(section: 'masnew_movies', timeout: timeout);
    await syncCatalog(section: 'masnew_featured', timeout: timeout);
    await syncCatalog(section: 'masnew_series', timeout: timeout);
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

  /// Momento en que se guardó la descarga más reciente. Null si todavía no hay ninguna.
  Future<DateTime?> lastSavedCatalogAt() async {
    try {
      final Directory? dir;
      if (_catalogDirectoryOverride != null) {
        dir = _catalogDirectoryOverride;
      } else {
        final support = await getApplicationSupportDirectory();
        final candidate = Directory('${support.path}/catalog');
        dir = candidate.existsSync() ? candidate : null;
      }
      if (dir == null || !dir.existsSync()) return null;

      DateTime? latest;
      for (final section in _persistableSections) {
        final file = File('${dir.path}/$section.json');
        if (!file.existsSync() || file.lengthSync() < 50) continue;
        final modified = file.lastModifiedSync();
        if (latest == null || modified.isAfter(latest)) {
          latest = modified;
        }
      }
      return latest;
    } catch (e) {
      logLine('No se pudo leer la fecha del catálogo: $e');
      return null;
    }
  }

  /// Lee la última descarga en vivo guardada por esta app. No incluye el respaldo empaquetado.
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
      logLine('Última descarga guardada: ${result.totalMovies} títulos ($section).');
      _cachedCatalog = result;
      return result;
    } catch (e) {
      logLine('No se pudo leer la copia guardada de $section: $e');
      return null;
    }
  }

  /// Última descarga guardada, o el respaldo empaquetado si todavía no hay ninguna.
  Future<CatalogResult> loadSavedOrBundled({
    String section = 'masnew_featured',
  }) async {
    final saved = await loadPersistedCatalog(section);
    if (saved != null) return saved;
    return loadFallbackCatalog(section: section);
  }

  CatalogResult _emptyCatalog(String sectionLabel) {
    return CatalogResult(
      categories: [],
      isFromNetwork: false,
      source: CatalogSource.assetBundle,
      statusMessage: 'Sin catálogo de $sectionLabel.',
    );
  }

  String _savedStatusMessage(String section) {
    final sectionLabel = section == 'masnew_featured'
        ? 'Destacados'
        : (section == 'masnew_series' ? 'Series' : 'Películas');
    return '$sectionLabel desde la última descarga guardada';
  }

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
        .map((e) => CategoryColumn.fromJson(e))
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

  /// Carga el catálogo desde la copia local empaquetada
  Future<CatalogResult> loadFallbackCatalog({
    String section = 'masnew_featured',
  }) async {
    final sectionLabel = section == 'masnew_featured'
        ? 'Destacados'
        : (section == 'masnew_series' ? 'Series' : 'Películas');

    try {
      final jsonString =
          await rootBundle.loadString('assets/data/$section.json');
      final data = jsonDecode(jsonString);

      if (data is Map<String, dynamic> && data['recommendList'] is List) {
        final list = (data['recommendList'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => CategoryColumn.fromJson(e))
            .where((cat) => cat.movies.isNotEmpty)
            .toList();

        final total = list.fold(0, (sum, c) => sum + c.movies.length);
        logLine('📦 Respaldo HARDCODEADO: $total títulos ($section).');
        final result = CatalogResult(
          categories: list,
          isFromNetwork: false,
          source: CatalogSource.assetBundle,
          statusMessage:
              '$sectionLabel HARDCODEADOS ($total títulos en ${list.length} categorías)',
        );
        _cachedCatalog ??= result;
        return result;
      }
    } catch (e) {
      logLine('❌ Error al cargar assets/data/$section.json: $e');
    }

    return CatalogResult(
      categories: [],
      isFromNetwork: false,
      source: CatalogSource.assetBundle,
      statusMessage: 'No se pudo cargar el catálogo de $sectionLabel.',
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
            logLine('✅ startPlayVOD éxito: "${info.name}" (${info.qualities.length} calidades, ${info.subtitles.length} subs)');
            return info;
          }
        } else {
          logLine('⚠️ startPlayVOD returnCode=$returnCode (${decoded['errorMessage']})');
          if (returnCode == 'aaa100028') {
            lastResolutionError = 'Sesión expirada o no autenticada.';
          } else if (decoded['errorMessage'] != null && decoded['errorMessage'].toString().isNotEmpty) {
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
        logLine('getSlbInfo ($mediaContentId) → $baseUrl (mac: $_deviceMac, sn: ${_currentSnField.isNotEmpty ? "OK" : "vacío"})');
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
              if (returnCode == '0' || returnCode == '0000' || returnCode == '200') {
                final data = _decodeData(decoded['data']);
                logLine('📦 getSlbInfo data completa ($version, $typeVal, $liveCode): ${jsonEncode(data)}');
                if (data is Map<String, dynamic> && data['cdn_list'] is List) {
                  final cdnList = (data['cdn_list'] as List).whereType<Map>().toList();
                  // Priorizar CDNs con tag="vod"
                  cdnList.sort((a, b) {
                    final aVod = a['tag']?.toString().toLowerCase() == 'vod' ? 0 : 1;
                    final bVod = b['tag']?.toString().toLowerCase() == 'vod' ? 0 : 1;
                    return aVod.compareTo(bVod);
                  });

                  for (final cdn in cdnList) {
                    if (cdn['url_list'] is List) {
                      var host = (cdn['main_addr'] ?? cdn['spared_addr'])?.toString().trim() ?? '';
                      if (host.startsWith('http://') || host.startsWith('https://')) {
                        host = host.replaceFirst(RegExp(r'^https?://'), '');
                      }
                      for (final u in cdn['url_list'] as List) {
                        if (u is Map && u['url'] != null) {
                          final urlStr = u['url'].toString().trim();
                          if (urlStr.startsWith('http://') || urlStr.startsWith('https://')) {
                            logLine('✅ getSlbInfo stream URL resuelta ($version, $typeVal): ${_short(urlStr, 80)}');
                            return urlStr;
                          } else if (host.isNotEmpty) {
                            final fullAuth = (license != null && license.isNotEmpty && !urlStr.contains('media_code'))
                                ? '$urlStr&$license'
                                : urlStr;
                            final streamUrl = 'http://$host/$mediaContentId.m3u8?$fullAuth';
                            logLine('✅ getSlbInfo stream URL armada ($version, $typeVal, tag=${cdn['tag']}): ${_short(streamUrl, 80)}');
                            return streamUrl;
                          }
                        }
                      }
                    }
                  }
                }
              } else {
                logLine('⚠️ getSlbInfo $version ($typeVal, $liveCode) returnCode=$returnCode (${decoded['errorMessage']})');
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
    logLine('🎬 Iniciando resolución de stream para: "${movie.name}" (ID: ${movie.contentId})');

    // Restaurar tokens de sesión activos si existen en almacenamiento
    await restoreSessionFromStorage();

    // Si no teníamos snField guardado de una sesión previa, vincularlo sin VPN
    if (_currentSnField.isEmpty) {
      logLine('↻ Obteniendo snToken para asociar dispositivo...');
      final fp = await _deviceFingerprint();
      final ioClient = HttpClient()..badCertificateCallback = ((c, h, p) => true);
      _trackClient(ioClient);
      try {
        final sn = await _fetchSnToken(ioClient, defaultBaseUrl, fp, const Duration(seconds: 4));
        if (sn != null && sn['_token'] != null) {
          final snToken = sn['_token'].toString();
          _currentSnField = _md5Hex('$snToken$kMoiamovSnSalt');
          _activeSnField = _currentSnField;
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('moiamov_sn_field', _currentSnField);
          prefs.setString('moiamov_device_mac', _deviceMac);
          logLine('✅ snField vinculado con MAC ($_deviceMac): ${_short(_currentSnField, 16)}');
        }
      } catch (e) {
        logLine('⚠️ Error obteniendo snToken: $e');
      } finally {
        _releaseClient(ioClient);
      }
    }

    // 1. startPlayVOD
    var playInfo = await startPlayVOD(contentId: movie.contentId, timeout: timeout);

    // Si falló por sesión no inicializada o expirada, intentamos reactivar una sola vez
    if (playInfo == null || playInfo.qualities.isEmpty) {
      logLine('↻ Intentando reactivación de sesión para VOD...');
      final activated = await activateDeviceSession(timeout: const Duration(seconds: 6));
      if (activated) {
        playInfo = await startPlayVOD(contentId: movie.contentId, timeout: timeout);
      }
    }

    if (playInfo == null || playInfo.qualities.isEmpty) {
      logLine('❌ No se encontraron calidades de reproducción para "${movie.name}"');
      lastResolutionError ??= 'No se encontraron opciones de reproducción para este título.';
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
        (q) => q.quality.toUpperCase().contains('1080') || q.quality.toUpperCase().contains('4K'),
        orElse: () => playInfo!.qualities.first,
      );
    }

    // 3. Selección de Audio (PLAN §3.Paso 2.B)
    final selectedSource = selectedQuality.bestAudioSource;
    if (selectedSource == null) {
      logLine('❌ La calidad ${selectedQuality.quality} no tiene pistas de audio válidas');
      lastResolutionError ??= 'No hay pistas de audio disponibles para esta película.';
      return null;
    }

    // 4. Selección de Subtítulos (PLAN §3.Paso 2.A)
    final bestSub = playInfo.bestSpanishSubtitle;
    logLine('🔊 Pista elegida: ${selectedQuality.quality} - ${selectedSource.audioInfo} (Media ID: ${selectedSource.mediaContentId})');
    if (bestSub != null) {
      logLine('💬 Subtítulo en español elegido: "${bestSub.name}" (${bestSub.language}) [URL: ${bestSub.url}]');
    }

    // 5. URL directa de startPlayVOD o getSlbInfo (PLAN §3.Paso 3)
    String? streamUrl = selectedSource.directUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      logLine('✅ URL directa encontrada en startPlayVOD: ${_short(streamUrl, 80)}');
    } else {
      streamUrl = await getSlbInfo(
        mediaContentId: selectedSource.mediaContentId,
        license: selectedSource.license,
        timeout: timeout,
      );
    }

    if (streamUrl == null) {
      logLine('❌ No se pudo obtener la URL de streaming');
      lastResolutionError ??= 'El servidor de streaming no devolvió un enlace válido.';
      return null;
    }

    return ResolvedPlayStream(
      streamUrl: streamUrl,
      quality: selectedQuality.quality,
      audioInfo: selectedSource.audioInfo,
      subtitleUrl: bestSub?.url,
      subtitleName: bestSub?.name,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36',
      },
    );
  }
}
