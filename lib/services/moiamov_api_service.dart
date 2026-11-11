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
import '../models/series_models.dart';
import 'moiamov_catalog_store.dart';
import 'moiamov_crypto.dart';
import 'titan_ranger_service.dart';
import 'titan_vod_preparer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

part 'moiamov/moiamov_session.dart';
part 'moiamov/moiamov_catalog.dart';
part 'moiamov/moiamov_playback.dart';

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
  /// [timeout] es para el pedido entero (antes era por etapa: abrir, enviar
  /// y leer sumaban hasta el triple con la red muda).
  Future<String?> _postEncrypted(
    HttpClient client,
    String url,
    Map<String, dynamic> payload,
    Duration timeout,
  ) async {
    try {
      final (resp, body) = await () async {
        final req = await client.postUrl(Uri.parse(url));
        _setCommonHeaders(req);
        req.write(encryptPayload(payload));
        final resp = await req.close();
        return (resp, await resp.transform(utf8.decoder).join());
      }().timeout(timeout);
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

  static String _md5Hex(String input) => MoiamovCrypto.md5Hex(input);

  /// 3DES con la clave indicada, como AbstractC4310b.m18077b del APK.
  static String _encryptWithKey(String plain, String key) =>
      MoiamovCrypto.encrypt(plain, key);

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

  /// La última sesión la rechazó el portal por la región o la IP de salida
  /// (`portal100024`): con esa salida no hay nada que hacer.
  bool lastSessionRegionRejected = false;

  /// Servidor del portal que dio la última sesión: se prueba primero en la
  /// próxima y lo usa la descarga del catálogo.
  String? _sessionHost;
  static const String _sessionHostKey = 'moiamov_session_host';

  /// Tiempo máximo para pasar al siguiente servidor del portal: con la red
  /// muda no tiene sentido recorrerlos todos.
  static const Duration _sessionBudget = Duration(seconds: 20);

  /// Tope para bajar una sección mientras siga llegando.
  static const Duration _catalogBodyCap = Duration(seconds: 90);

  /// El catálogo guardado en disco.
  late final MoiamovCatalogStore _store = MoiamovCatalogStore(logLine);

  static MovieSearchPage _searchPageFrom(Object? data, String untitled) {
    if (data is! Map) return const MovieSearchPage(items: [], total: 0);
    final items = <MovieItem>[
      for (final group in (data['searchItemList'] as List?) ?? const [])
        if (group is Map)
          for (final raw in (group['itemList'] as List?) ?? const [])
            if (raw is Map<String, dynamic>) _searchItem(raw, untitled),
    ];
    final total = int.tryParse('${data['totalSize']}') ?? items.length;
    return MovieSearchPage(items: items, total: total);
  }

  static List<MovieItem>? _shelfMoviesFrom(Object? data, String untitled) {
    if (data is! Map) return null;
    return [
      for (final raw in (data['assetList'] as List?) ?? const [])
        if (raw is Map<String, dynamic>)
          if (_searchItem(raw, untitled) case final item
              when !item.isCatalogTrailer && !item.isTrailer)
            item,
    ];
  }

  static int? _shelfTotalFrom(Object? data, String untitled) =>
      data is Map ? int.tryParse('${data['assetListTotalSize'] ?? ''}') : null;

  static SeriesSeasonDetail? _seriesSeasonFrom(Object? data, String untitled) {
    final asset = data is Map ? data['assetData'] : null;
    if (asset is! Map<String, dynamic>) return null;
    return SeriesSeasonDetail.fromAsset(asset, _searchItem(asset, untitled));
  }

  /// Lo que arma [build] con la `data` de `v3/getShelveData`; `null` si no hay
  /// sesión o falla.
  Future<T?> _shelfData<T>(
    int columnId,
    int page,
    int pageSize,
    Duration timeout,
    T? Function(Object? data, String untitled) build,
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
    return _readReply(body, 'getShelveData $columnId', build);
  }

  /// Lee una respuesta del portal en otro hilo: el 3DES es lento y, con
  /// decenas de pedidos al cargar Películas, trababa la pantalla. [build] debe
  /// ser una función estática y pura, y lo que arma vuelve a este hilo.
  /// `null` si el portal la rechazó o no se pudo leer.
  static Future<T?> _readReply<T>(
    String body,
    String label,
    T? Function(Object? data, String untitled) build, {
    String? key,
  }) async {
    final portal = key ?? portalKey;
    // Allá no hay traducciones.
    final untitled = LocaleKeys.movies_untitled.tr();
    try {
      final reply = await Isolate.run(
        () => _parseReply<T>(body, portal, untitled, build),
      );
      if (reply.rejection case final rejection?) {
        logLine('$label rechazado: $rejection');
      }
      if (reply.decryptError case final error?) {
        logLine('⚠️ No se pudo descifrar data del server: $error');
      }
      return reply.value;
    } catch (e) {
      logLine('⚠️ $label: respuesta inválida: $e');
      return null;
    }
  }

  static _PortalReply<T> _parseReply<T>(
    String body,
    String key,
    String untitled,
    T? Function(Object? data, String untitled) build,
  ) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return _PortalReply<T>();
    if (decoded['returnCode']?.toString() != '0') {
      return _PortalReply<T>(
        rejection: '${decoded['returnCode']} (${decoded['errorMessage']})',
      );
    }
    Object? data = decoded['data'];
    String? decryptError;
    if (data is String && data.trim().isNotEmpty) {
      try {
        data = jsonDecode(MoiamovCrypto.decrypt(data.trim(), key));
      } catch (e) {
        data = null;
        decryptError = '$e';
      }
    }
    return _PortalReply<T>(
      value: build(data, untitled),
      decryptError: decryptError,
    );
  }

  /// [_readReply] de una página de `getShelveData`, con una clave de prueba.
  @visibleForTesting
  static Future<List<MovieItem>?> debugReadShelf(
    String body, {
    required String key,
  }) => _readReply(body, 'getShelveData', _shelfMoviesFrom, key: key);

  /// Los resultados traen el estreno (`releaseTime`), que el catálogo no.
  static MovieItem _searchItem(Map<String, dynamic> raw, String untitled) {
    final released = raw['releaseTime']?.toString() ?? '';
    final year = RegExp(r'\b(19|20)\d\d\b').firstMatch(released)?.group(0);
    return MovieItem.fromJson(
      year == null ? raw : {...raw, 'year': year},
      untitled: untitled,
    );
  }

  static String _sectionLabel(String section) =>
      MoiamovCatalogStore.sectionLabel(section);

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
}

/// Una respuesta del portal leída en otro hilo ([MoiamovApiService]): los
/// avisos se escriben al volver.
class _PortalReply<T> {
  const _PortalReply({this.value, this.rejection, this.decryptError});

  final T? value;

  /// El portal la rechazó: su código y mensaje.
  final String? rejection;

  /// No se pudo descifrar `data`.
  final String? decryptError;
}
