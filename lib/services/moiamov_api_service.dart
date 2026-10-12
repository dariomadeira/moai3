import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/digests/md5.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';

/// Servicio de sincronización del catálogo de películas y series Moiamov
/// con cifrado nativo Triple DES (3DES) y autenticación automática.
class MoiamovApiService {
  static final MoiamovApiService instance = MoiamovApiService._internal();

  MoiamovApiService._internal();

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

  CatalogResult? _cachedCatalog;
  CatalogResult? get cachedCatalog => _cachedCatalog;

  /// Evita reactivar en bucle (el servidor corta el TLS si se lo bombardea).
  bool _reactivationTried = false;

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
    mergedMap.putIfAbsent('loginType', () => '1');
    mergedMap.putIfAbsent('appLanguage', () => 'es');
    mergedMap.putIfAbsent('apkVersion', () => apkVer);
    mergedMap.putIfAbsent('sysVersion', () => spkgVer);
    mergedMap.putIfAbsent('appId', () => apkPackage);
    mergedMap.putIfAbsent('hardwareInfo', () => 'x86_64');
    mergedMap.putIfAbsent('model', () => 'Television');
    mergedMap.putIfAbsent('product', () => 'sdk_google');
    mergedMap.putIfAbsent('abi', () => 'x86_64');
    mergedMap.putIfAbsent('deviceToken', () => '1fb16e34b8dd3831');
    mergedMap.putIfAbsent('sn', () => '');
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
    final pcl = data['portalCodeList'];
    if (pcl is List && pcl.isNotEmpty && pcl[0] is Map && pcl[0]['portalCode'] != null) {
      _currentPortalCode = pcl[0]['portalCode'].toString();
    } else if (data['portalCode'] != null) {
      _currentPortalCode = data['portalCode'].toString();
    }
    logLine('✅ Sesión activada: userId=$_currentUserId portal=$_currentPortalCode');
    return true;
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
      final baseUrl = _cleanUrl(host);
      final ioClient = HttpClient()
        ..badCertificateCallback = ((cert, h, p) => true)
        ..connectionTimeout = timeout;
      try {
        logLine('Sesión: v3/snToken → $baseUrl');
        final sn = await _fetchSnToken(ioClient, baseUrl, fp, timeout);
        if (sn == null) continue;
        final snToken = sn['_token']?.toString() ?? '';
        if (snToken.isEmpty) continue;

        // Campo `sn` requerido por el envelope (C1446c0.m6748t = KEY_SP_SN):
        // MD5(snToken + salt) en minúscula, calculado por C0132a1 tras v3/snToken.
        final snField = _md5Hex('$snToken$kMoiamovSnSalt');
        final localMac = _deviceMac.replaceAll(':', '');
        final reserve1 = _encryptWithKey(
            localMac.isEmpty ? '000000000000' : localMac,
            kMoiamovDeviceCipherKey);
        final b29 = _encryptWithKey(
            (fp['serialNumber'] ?? '').isEmpty ? '000000000000' : fp['serialNumber']!,
            kMoiamovDeviceCipherKey);

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
          return false;
        }
        if (_applyActiveResult(actDecoded)) {
          return true;
        }
        logLine('active rechazado: $rc ($em)');
      } catch (e) {
        logLine('Sesión: excepción en $host: $e');
      } finally {
        ioClient.close();
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
        logLine('getNextColumns $sectionLabel: código "$code" → $host');

        final ioClient = HttpClient()
          ..badCertificateCallback = ((cert, h, p) => true)
          ..connectionTimeout = timeout;

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
          ioClient.close();
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    // 2. Almacenamiento local del dispositivo
    logLine('ℹ️ API en vivo no devolvió $sectionLabel. Probando cache local del TV...');
    final localLive = _loadFromLocalDeviceDocument(section);
    if (localLive != null) {
      return localLive;
    }

    // 3. Prioridad 3: Respaldo empaquetado
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
}
