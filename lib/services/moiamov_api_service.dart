import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/movie_models.dart';
import 'moiamov_catalog_store.dart';
import 'moiamov_crypto.dart';
import 'titan_ranger_service.dart';
import 'titan_vod_preparer.dart';
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
    _vodHttp = null;
    for (final client in _liveClients.toList()) {
      try {
        client.close(force: true);
      } catch (_) {}
    }
  }

  /// Servidores a los que ya se les aceptó un certificado no válido.
  static final Set<String> _badCertHosts = {};

  /// Acepta un certificado no válido del portal (algunos servidores lo
  /// tienen vencido o autofirmado) y lo deja una vez en el log por servidor:
  /// así se sabe cuáles lo necesitan para limitarlo a esos.
  static bool _acceptPortalCert(X509Certificate cert, String host, int port) {
    if (_badCertHosts.add(host)) {
      logLine('⚠️ Certificado no válido aceptado: $host (${cert.issuer})');
    }
    return true;
  }

  HttpClient? _vodHttp;

  /// Cliente de los pedidos de reproducción, compartido para no negociar TLS
  /// en cada uno. Las conexiones ociosas se cierran a los 20 s; cancelar las
  /// descargas lo cierra y el próximo pedido abre otro.
  HttpClient get _vodClient {
    final existing = _vodHttp;
    if (existing != null) return existing;
    final client = HttpClient()
      ..badCertificateCallback = _acceptPortalCert
      ..connectionTimeout = const Duration(seconds: 14)
      ..idleTimeout = const Duration(seconds: 20);
    _trackClient(client);
    return _vodHttp = client;
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

  /// Descifra cadenas o documentos cifrados con Triple DES (ECB + PKCS7).
  static String decryptDocument(String hexData, {String? key}) =>
      MoiamovCrypto.decrypt(hexData, key ?? localDocumentKey);

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

    return MoiamovCrypto.encrypt(jsonEncode(mergedMap), portalKey);
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
        _portalRejections++;
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
      _portalRejections++;
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

  static String _md5Hex(String input) => MoiamovCrypto.md5Hex(input);

  /// 3DES con la clave indicada, como AbstractC4310b.m18077b del APK.
  static String _encryptWithKey(String plain, String key) =>
      MoiamovCrypto.encrypt(plain, key);

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
  /// Rechazos explícitos del portal (contestó que no). Sirve para saber si
  /// una sesión fallida fue un rechazo o un corte de red.
  int _portalRejections = 0;

  /// La última sesión que falló fue sólo por la red (tiempos agotados,
  /// conexión cortada en el TLS): un corte pasajero, típico apenas sube la
  /// VPN. Si el portal la rechazó explícitamente, es false.
  bool lastSessionNetworkFailure = false;

  Future<bool> activateDeviceSession({
    String? serverUrl,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final rejectionsBefore = _portalRejections;
    final ok = await _activateDeviceSession(
      serverUrl: serverUrl,
      timeout: timeout,
    );
    lastSessionNetworkFailure = !ok && _portalRejections == rejectionsBefore;
    return ok;
  }

  Future<bool> _activateDeviceSession({
    String? serverUrl,
    required Duration timeout,
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
        ..badCertificateCallback = _acceptPortalCert
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
          _portalRejections++;
          logLine(
            '🚫 La salida de red fue rechazada. Reintentá con otro nodo.',
          );
          lastResolutionError = LocaleKeys.movies_error_region.tr();
          return false;
        }
        if (_applyActiveResult(actDecoded)) {
          return true;
        }
        _portalRejections++;
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
          ..badCertificateCallback = _acceptPortalCert
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
          // Los bytes tal cual: pasarlos a texto también va en el otro hilo.
          final body = await response
              .fold(BytesBuilder(copy: false), (b, chunk) => b..add(chunk))
              .timeout(timeout);

          if (response.statusCode != 200) {
            logLine('⚠️ HTTP ${response.statusCode} ($host / $code)');
            continue;
          }

          // El catálogo pesa cientos de KB cifrados en 3DES. Leerlo,
          // descifrarlo, contarlo y guardarlo va todo en otro hilo: acá
          // vuelve sólo un resumen y la pantalla no se traba. La clave y la
          // ruta se leen desde acá (allá no hay .env ni path_provider).
          final key = portalKey;
          final savePath = await _store.pathFor(section);
          final bytes = body.takeBytes();
          final download = await Isolate.run(
            () => MoiamovCatalogStore.processDownload(
              bytes,
              key: key,
              savePath: savePath,
            ),
          );
          final returnCode = download.returnCode;
          if (returnCode == null) continue;
          final errMsg = download.errorMessage;
          logLine(
            '↳ returnCode=$returnCode${errMsg != null ? ' ($errMsg)' : ''}',
          );
          if (download.decryptError != null) {
            logLine(
              '⚠️ No se pudo descifrar data del server: ${download.decryptError}',
            );
          }

          if (download.ok) {
            if (download.titles > 0) {
              final total = download.titles;
              final cats = download.categories;
              logLine(
                '✅ EN VIVO: $total títulos en $cats categorías ($sectionLabel)',
              );
              if (download.saved) {
                logLine('Guardada última descarga de $section.');
              }
              // Sólo dice que bajó: las películas se arman al abrir la
              // sección, desde el disco (antes se armaban acá y se tiraban).
              return CatalogResult(
                categories: const [],
                isFromNetwork: true,
                source: CatalogSource.liveApi,
                statusMessage:
                    '$sectionLabel ACTUALIZADO EN VIVO ($total títulos en $cats categorías)',
              );
            }
            logLine(
              '⚠️ Respuesta OK pero sin títulos ($sectionLabel / $code).',
            );
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

  /// El catálogo guardado en disco.
  late final MoiamovCatalogStore _store = MoiamovCatalogStore(logLine);

  /// Carpeta de prueba. En la app se usa el directorio privado de soporte.
  @visibleForTesting
  void debugSetCatalogDirectory(Directory? directory) =>
      _store.debugSetDirectory(directory);

  /// Fecha del catálogo: se guarda solo cuando bajan las 3 secciones.
  /// Null si todavía no hubo una descarga completa.
  Future<DateTime?> lastSavedCatalogAt() => _store.lastSavedAt();

  Future<void> saveCatalogDate(DateTime date) => _store.saveDate(date);

  /// Secciones que tienen una descarga guardada en disco.
  Future<Set<String>> savedSections() => _store.savedSections();

  /// Lee la última descarga en vivo guardada por esta app.
  Future<CatalogResult?> loadPersistedCatalog(String section) async {
    final result = await _store.load(section);
    if (result != null) _cachedCatalog = result;
    return result;
  }

  /// Búsqueda en toda la biblioteca (`v3/searchByName`), como la app oficial.
  /// Trae películas y series mezcladas, sin limpiar (SPEC-45 §4). Funciona con
  /// la sesión del arranque, sin VPN. `null` si no hay sesión o el portal no
  /// contesta bien.
  Future<MovieSearchPage?> searchMovies(
    String query, {
    int page = 1,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_currentUserToken.isEmpty) return null;
    final body = await _postEncrypted(
      _vodClient,
      '${_cleanUrl(defaultBaseUrl)}/api/portalCore/v3/searchByName',
      {
        'userToken': _currentUserToken,
        'userId': _currentUserId,
        'portalCode': _currentPortalCode,
        'columnId': '-1',
        'value': query,
        'type': '1',
        'pageSize': MovieSearchPage.pageSize,
        'pageNum': page,
        'filter': '',
      },
      timeout,
    );
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['returnCode']?.toString() != '0') {
        logLine(
          'searchByName rechazado: ${decoded['returnCode']} (${decoded['errorMessage']})',
        );
        return null;
      }
      final data = _decodeData(decoded['data']);
      if (data is! Map) return const MovieSearchPage(items: [], total: 0);
      final items = <MovieItem>[
        for (final group in (data['searchItemList'] as List?) ?? const [])
          if (group is Map)
            for (final raw in (group['itemList'] as List?) ?? const [])
              if (raw is Map<String, dynamic>) _searchItem(raw),
      ];
      final total = int.tryParse('${data['totalSize']}') ?? items.length;
      return MovieSearchPage(items: items, total: total);
    } catch (e) {
      logLine('⚠️ searchByName: respuesta inválida: $e');
      return null;
    }
  }

  /// Películas de una categoría del catálogo, paginadas (`v3/getShelveData`,
  /// SPEC-45 §8). `columnType` va `"2"`: con `"movie"` el servidor contesta
  /// bien pero vacío. La página 1 empieza con las mismas películas que la
  /// fila del catálogo. `null` si no hay sesión o el pedido falla.
  Future<List<MovieItem>?> fetchShelf(
    int columnId, {
    int page = 1,
    required int pageSize,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final data = await _shelfData(columnId, page, pageSize, timeout);
    if (data == null) return null;
    return [
      for (final raw in (data['assetList'] as List?) ?? const [])
        if (raw is Map<String, dynamic>)
          if (_searchItem(raw) case final movie when movie.isMovie) movie,
    ];
  }

  /// Cuántas películas tiene la categoría (`assetListTotalSize`); pide una
  /// sola para que la respuesta sea liviana. `null` si falla.
  Future<int?> fetchShelfTotal(
    int columnId, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final data = await _shelfData(columnId, 1, 1, timeout);
    return int.tryParse('${data?['assetListTotalSize'] ?? ''}');
  }

  /// `data` descifrada de `v3/getShelveData`; `null` si no hay sesión o falla.
  Future<Map?> _shelfData(
    int columnId,
    int page,
    int pageSize,
    Duration timeout,
  ) async {
    if (_currentUserToken.isEmpty || columnId <= 0) return null;
    final body = await _postEncrypted(
      _vodClient,
      '${_cleanUrl(defaultBaseUrl)}/api/portalCore/v3/getShelveData',
      {
        'userToken': _currentUserToken,
        'userId': _currentUserId,
        'portalCode': _currentPortalCode,
        'columnId': columnId,
        'columnType': '2',
        'pageSize': pageSize,
        'pageNum': page,
        'numDisplay': pageSize,
        'encryptVersion': 1,
      },
      timeout,
    );
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['returnCode']?.toString() != '0') {
        logLine(
          'getShelveData $columnId rechazado: ${decoded['returnCode']} (${decoded['errorMessage']})',
        );
        return null;
      }
      final data = _decodeData(decoded['data']);
      return data is Map ? data : null;
    } catch (e) {
      logLine('⚠️ getShelveData $columnId: respuesta inválida: $e');
      return null;
    }
  }

  /// Los resultados traen el estreno (`releaseTime`), que el catálogo no.
  static MovieItem _searchItem(Map<String, dynamic> raw) {
    final released = raw['releaseTime']?.toString() ?? '';
    final year = RegExp(r'\b(19|20)\d\d\b').firstMatch(released)?.group(0);
    return MovieItem.fromJson(year == null ? raw : {...raw, 'year': year});
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

  static String _sectionLabel(String section) =>
      MoiamovCatalogStore.sectionLabel(section);

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
      // Cliente compartido: reusa la conexión TLS entre los pedidos de
      // una reproducción (startPlayVOD → getSlbInfo).
      final ioClient = _vodClient;

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
            // Trae licencias y tokens: sólo en debug.
            if (kDebugMode) {
              logLine('📦 startPlayVOD data completa: ${jsonEncode(data)}');
            }
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
            lastResolutionError = LocaleKeys.movies_error_session_expired.tr();
          } else if (decoded['errorMessage'] != null &&
              decoded['errorMessage'].toString().isNotEmpty) {
            lastResolutionError = decoded['errorMessage'].toString();
          }
        }
      } catch (e) {
        logLine('⚠️ Error en startPlayVOD ($host): $e');
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
      // Cliente compartido: reusa la conexión TLS entre los pedidos de
      // una reproducción (startPlayVOD → getSlbInfo).
      final ioClient = _vodClient;

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
      // Cliente compartido: reusa la conexión TLS entre los pedidos de
      // una reproducción (startPlayVOD → getSlbInfo).
      final ioClient = _vodClient;

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
      }
    }
    return null;
  }

  /// Resuelve la URL y metadatos de reproducción listos para el reproductor nativo.
  /// Implementa las reglas del PLAN DE IMPLEMENTACIÓN:
  /// - Jerarquía estricta de subtítulos en español (Latino > Neutro > España)
  /// - Audio en español prioritario
  /// - Calidad según preferencia (1080p / 720p)
  /// La mejor calidad para la TV: 1080p si está; 4K sólo si no hay otra
  /// alta (un Chromecast HD no lo decodifica y el buffer pesa el triple);
  /// si no, la primera.
  @visibleForTesting
  static VodQualityOption pickBestQuality(List<VodQualityOption> qualities) {
    bool has(VodQualityOption q, String tag) =>
        q.quality.toUpperCase().contains(tag);
    for (final tag in const ['1080', '4K', '2160']) {
      for (final q in qualities) {
        if (has(q, tag)) return q;
      }
    }
    return qualities.first;
  }

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
      final ioClient = HttpClient()..badCertificateCallback = _acceptPortalCert;
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
      lastResolutionError ??= LocaleKeys.movies_error_no_play_options.tr();
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
      selectedQuality = pickBestQuality(playInfo.qualities);
    }

    // 3. Selección de Audio (PLAN §3.Paso 2.B)
    final selectedSource = selectedQuality.bestAudioSource;
    if (selectedSource == null) {
      logLine(
        '❌ La calidad ${selectedQuality.quality} no tiene pistas de audio válidas',
      );
      lastResolutionError ??= LocaleKeys.movies_error_no_audio.tr();
      return null;
    }

    // 4. Subtítulos: van todos; el reproductor elige según el ajuste.
    final subtitles = [
      for (final s in playInfo.subtitles)
        if (s.url.isNotEmpty) s,
    ];
    logLine(
      '🔊 Pista elegida: ${selectedQuality.quality} - ${selectedSource.audioInfo} (Media ID: ${selectedSource.mediaContentId})',
    );
    logLine(
      '💬 Subtítulos: ${subtitles.isEmpty ? 'ninguno' : subtitles.map((s) => s.language).join(', ')}',
    );

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

          if (slbData != null) {
            final prepared = await TitanVodPreparer.prepare(
              slbData: slbData,
              movie: movie,
              quality: selectedQuality,
              source: selectedSource,
              app: apkPackage,
              appVer: apkVer,
              userId: _currentUserId,
              devId: _deviceMac,
              portalKey: portalKey,
              log: logLine,
            );
            if (prepared.error != null) lastResolutionError = prepared.error;
            if (prepared.playUrl != null) streamUrl = prepared.playUrl;
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
      lastResolutionError ??= LocaleKeys.movies_error_unresolved_stream.tr();
      return null;
    }

    return ResolvedPlayStream(
      streamUrl: streamUrl,
      quality: selectedQuality.quality,
      audioInfo: selectedSource.audioInfo,
      subtitles: subtitles,
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
