part of '../moiamov_api_service.dart';

/// La sesión del dispositivo: huella, snToken y activación (v8/active).
extension MoiamovSession on MoiamovApiService {
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
        'wifiMac': MoiamovApiService._deviceMac,
        'etheMac': (fp['etheMac'] ?? '').isEmpty
            ? MoiamovApiService._deviceMac
            : fp['etheMac'],
        'serialNumber': fp['serialNumber'],
        'diskInfo': fp['diskInfo'],
        'ramSize': fp['ramSize'],
        'romSize': fp['romSize'],
        'gatewayMac': (fp['gatewayMac'] ?? '').isEmpty
            ? MoiamovApiService._deviceMac
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
    MoiamovApiService.logLine(
      'v3/snToken resp: ${MoiamovApiService._short(body)}',
    );
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['returnCode']?.toString() != '0') {
      _portalRejections++;
      MoiamovApiService.logLine(
        'snToken rechazado: ${decoded['returnCode']} (${decoded['errorMessage']})',
      );
      return null;
    }
    final data = _decodeData(decoded['data']);
    if (data is! Map<String, dynamic>) {
      MoiamovApiService.logLine(
        'snToken sin data (crudo=${MoiamovApiService._short(decoded['data']?.toString() ?? 'null')})',
      );
      return null;
    }
    final snToken = data['snToken']?.toString() ?? '';
    final sn = data['sn']?.toString() ?? '';
    final token = snToken.isNotEmpty ? snToken : sn;
    if (token.isEmpty) {
      MoiamovApiService.logLine(
        'snToken sin token en respuesta (isNew=${data['isNew']})',
      );
      return null;
    }
    MoiamovApiService.logLine(
      '✅ snToken obtenido: $token${sn.isNotEmpty ? ' (sn=$sn)' : ''}',
    );
    return <String, dynamic>{...data, '_token': token};
  }

  /// Descifra el campo `data` de una respuesta del portal. El server SIEMPRE
  /// devuelve `data` como hex del payload 3DES (igual que el cliente oficial).
  dynamic _decodeData(dynamic data) {
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(
          MoiamovApiService.decryptDocument(
            data.trim(),
            key: MoiamovApiService.portalKey,
          ),
        );
      } catch (e) {
        MoiamovApiService.logLine(
          '⚠️ No se pudo descifrar data del server: $e',
        );
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
    MoiamovApiService.logLine(
      '✅ Sesión activada: userId=$_currentUserId portal=$_currentPortalCode identity=$_currentUserIdentity mac=${MoiamovApiService._deviceMac}',
    );
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('moiamov_user_id', _currentUserId);
        prefs.setString('moiamov_user_token', _currentUserToken);
        prefs.setString('moiamov_portal_code', _currentPortalCode);
        prefs.setString('moiamov_user_identity', _currentUserIdentity);
        prefs.setString('moiamov_device_mac', MoiamovApiService._deviceMac);
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
          MoiamovApiService._deviceMac = savedMac;
        }
        final savedSn = prefs.getString('moiamov_sn_field');
        if (savedSn != null && savedSn.isNotEmpty) {
          _currentSnField = savedSn;
          MoiamovApiService._activeSnField = savedSn;
        }
        _currentB29 = prefs.getString('moiamov_b29') ?? '';
        MoiamovApiService.logLine(
          '🔑 Sesión activa restaurada: userId=$_currentUserId portal=$_currentPortalCode mac=${MoiamovApiService._deviceMac} sn=${_currentSnField.isNotEmpty ? "OK" : "vacío"}',
        );
      }

      // Si la MAC sigue siendo la default, consultar fingerprint nativo de inmediato
      if (MoiamovApiService._deviceMac == MoiamovApiService.deviceMac) {
        final fp = await MoiamovApiService._deviceFingerprint();
        final realMac =
            (fp['wifiMac'] ?? '').isEmpty ||
                fp['wifiMac'] == '02:00:00:00:00:00'
            ? (fp['etheMac'] ?? MoiamovApiService.deviceMac)
            : (fp['wifiMac'] ?? MoiamovApiService.deviceMac);
        if (realMac.isNotEmpty && realMac != '02:00:00:00:00:00') {
          MoiamovApiService._deviceMac = realMac;
        }
      }
    } catch (e) {
      MoiamovApiService.logLine('⚠️ Error al restaurar sesión: $e');
    }
  }

  Future<bool> activateDeviceSession({
    String? serverUrl,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final rejectionsBefore = _portalRejections;
    lastSessionRegionRejected = false;
    final ok = await _activateDeviceSession(
      serverUrl: serverUrl,
      timeout: timeout,
    );
    lastSessionNetworkFailure = !ok && _portalRejections == rejectionsBefore;
    return ok;
  }

  Future<String?> _savedSessionHost() async {
    if (_sessionHost != null) return _sessionHost;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _sessionHost = prefs.getString(MoiamovApiService._sessionHostKey);
    } catch (_) {
      return null;
    }
  }

  void _rememberSessionHost(String baseUrl) {
    if (_sessionHost == baseUrl) return;
    _sessionHost = baseUrl;
    SharedPreferences.getInstance()
        .then(
          (prefs) =>
              prefs.setString(MoiamovApiService._sessionHostKey, baseUrl),
        )
        .catchError((_) => false);
  }

  Future<bool> _activateDeviceSession({
    String? serverUrl,
    required Duration timeout,
  }) async {
    final started = DateTime.now();
    final lastGood = serverUrl == null ? await _savedSessionHost() : null;
    final fp = await MoiamovApiService._deviceFingerprint();
    MoiamovApiService.logLine(
      'Dispositivo: androidId=${fp['androidId']} brand=${fp['brand']} device=${fp['device']}',
    );
    MoiamovApiService._deviceMac =
        (fp['wifiMac'] ?? '').isEmpty || fp['wifiMac'] == '02:00:00:00:00:00'
        ? (fp['etheMac'] ?? MoiamovApiService.deviceMac)
        : (fp['wifiMac'] ?? MoiamovApiService.deviceMac);

    final candidateHosts = <String>{
      ?lastGood,
      serverUrl ?? MoiamovApiService.defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.map(_cleanUrl).toSet().toList();

    for (final host in candidateHosts) {
      if (_syncCancelled) return false;
      if (host != candidateHosts.first &&
          DateTime.now().difference(started) >
              MoiamovApiService._sessionBudget) {
        MoiamovApiService.logLine(
          'Sesión: se agotó el tiempo; no se prueban más servidores.',
        );
        break;
      }
      final baseUrl = host;
      final ioClient = HttpClient()
        ..badCertificateCallback = MoiamovApiService._acceptPortalCert
        ..connectionTimeout = timeout;
      _trackClient(ioClient);
      try {
        MoiamovApiService.logLine('Sesión: v3/snToken → $baseUrl');
        final sn = await _fetchSnToken(ioClient, baseUrl, fp, timeout);
        if (sn == null) continue;
        final snToken = sn['_token']?.toString() ?? '';
        if (snToken.isEmpty) continue;

        // Campo `sn` requerido por el envelope (C1446c0.m6748t = KEY_SP_SN):
        // MD5(snToken + salt) en minúscula, calculado por C0132a1 tras v3/snToken.
        final snField = MoiamovApiService._md5Hex('$snToken$kMoiamovSnSalt');
        _currentSnField = snField;
        MoiamovApiService._activeSnField = snField;
        final localMac = MoiamovApiService._deviceMac.replaceAll(':', '');
        final reserve1 = MoiamovApiService._encryptWithKey(
          localMac.isEmpty ? '000000000000' : localMac,
          kMoiamovDeviceCipherKey,
        );
        final b29 = MoiamovApiService._encryptWithKey(
          (fp['serialNumber'] ?? '').isEmpty
              ? '000000000000'
              : fp['serialNumber']!,
          kMoiamovDeviceCipherKey,
        );
        _currentB29 = b29;

        MoiamovApiService.logLine('Sesión: v8/active → $baseUrl');
        final actBody = await _postEncrypted(
          ioClient,
          '$baseUrl/api/portalCore/v8/active',
          <String, dynamic>{
            'loginType': '2',
            'snToken': snToken,
            'authVersion': '',
            'authCode': '',
            'preCode': '',
            'macAddr': MoiamovApiService._deviceMac,
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
        MoiamovApiService.logLine(
          'v8/active resp: ${MoiamovApiService._short(actBody)}',
        );
        final actDecoded = jsonDecode(actBody);
        if (actDecoded is! Map<String, dynamic>) continue;
        final rc = actDecoded['returnCode']?.toString() ?? '';
        final em = actDecoded['errorMessage']?.toString() ?? '';
        if (rc == 'portal100024' || em.contains('黑名单') || em.contains('区域')) {
          _portalRejections++;
          lastSessionRegionRejected = true;
          MoiamovApiService.logLine(
            '🚫 La salida de red fue rechazada. Reintentá con otro nodo.',
          );
          lastResolutionError = LocaleKeys.movies_error_region.tr();
          return false;
        }
        if (_applyActiveResult(actDecoded)) {
          _rememberSessionHost(baseUrl);
          return true;
        }
        _portalRejections++;
        MoiamovApiService.logLine('active rechazado: $rc ($em)');
      } catch (e) {
        MoiamovApiService.logLine('Sesión: excepción en $host: $e');
      } finally {
        _releaseClient(ioClient);
      }
    }
    MoiamovApiService.logLine('⚠️ No se pudo activar sesión en ningún host.');
    return false;
  }

  /// Asegura una sesión activa y autenticada del dispositivo
  Future<bool> ensureSession({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return await activateDeviceSession(timeout: timeout);
  }
}
