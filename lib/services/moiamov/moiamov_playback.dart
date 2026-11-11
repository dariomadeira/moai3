part of '../moiamov_api_service.dart';

/// La reproducción: calidades (v10), servidores (SLB) y la URL final.
extension MoiamovPlayback on MoiamovApiService {
  /// Consulta las calidades, audios y subtítulos disponibles de una película (v10).
  Future<VodPlayInfo?> startPlayVOD({
    required String contentId,
    String type = '1',
    int columnId = -1,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final candidateHosts = <String>{
      MoiamovApiService.defaultBaseUrl,
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

        MoiamovApiService.logLine('startPlayVOD ($contentId) → $baseUrl');
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
              MoiamovApiService.logLine(
                '📦 startPlayVOD data completa: ${jsonEncode(data)}',
              );
            }
            final info = VodPlayInfo.fromJson(data);
            MoiamovApiService.logLine(
              '✅ startPlayVOD éxito: "${info.name}" (${info.qualities.length} calidades, ${info.subtitles.length} subs)',
            );
            return info;
          }
        } else {
          MoiamovApiService.logLine(
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
        MoiamovApiService.logLine('⚠️ Error en startPlayVOD ($host): $e');
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
    final localMac = MoiamovApiService._deviceMac.replaceAll(':', '');
    final reserve1 = MoiamovApiService._encryptWithKey(
      localMac.isEmpty ? '000000000000' : localMac,
      kMoiamovDeviceCipherKey,
    );

    final candidateHosts = <String>{
      MoiamovApiService.defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
    }.toList();

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      // Cliente compartido: reusa la conexión TLS entre los pedidos de
      // una reproducción (startPlayVOD → getSlbInfo).
      final ioClient = _vodClient;

      try {
        MoiamovApiService.logLine(
          'getSlbInfo ($mediaContentId) → $baseUrl (mac: ${MoiamovApiService._deviceMac}, sn: ${_currentSnField.isNotEmpty ? "OK" : "vacío"})',
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
              'appVer': MoiamovApiService.apkVer,
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
                MoiamovApiService.logLine(
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
                            MoiamovApiService.logLine(
                              '✅ getSlbInfo stream URL directa ($version, $typeVal): ${MoiamovApiService._short(urlStr, 80)}',
                            );
                            return urlStr;
                          }
                        }
                      }
                    }
                  }

                  MoiamovApiService.logLine(
                    '⚠️ getSlbInfo: el CDN solo entregó tokens firmados '
                    '(tag=${cdnList.isNotEmpty ? cdnList.first['tag'] : '-'}); '
                    'se requiere Titan Ranger para resolver el play_url.',
                  );
                }
              } else {
                MoiamovApiService.logLine(
                  '⚠️ getSlbInfo $version ($typeVal, $liveCode) returnCode=$returnCode (${decoded['errorMessage']})',
                );
              }
            }
          }
        }
      } catch (e) {
        MoiamovApiService.logLine('⚠️ Error en getSlbInfo ($host): $e');
      }
    }
    return null;
  }

  /// Obtiene la respuesta de datos completa (cdn_list, play_params) de getSlbInfo (v14/v15).
  Future<Map<String, dynamic>?> getSlbInfoRaw({
    required String mediaContentId,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final localMac = MoiamovApiService._deviceMac.replaceAll(':', '');
    final reserve1 = MoiamovApiService._encryptWithKey(
      localMac.isEmpty ? '000000000000' : localMac,
      kMoiamovDeviceCipherKey,
    );

    final candidateHosts = <String>{
      MoiamovApiService.defaultBaseUrl,
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
              'appVer': MoiamovApiService.apkVer,
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
        MoiamovApiService.logLine('⚠️ Error en getSlbInfoRaw ($host): $e');
      }
    }
    return null;
  }

  Future<ResolvedPlayStream?> resolveMovieStream({
    required MovieItem movie,
    String preferredQuality = 'max',
    Duration timeout = const Duration(seconds: 14),
  }) async {
    lastResolutionError = null;
    MoiamovApiService.logLine(
      '🎬 Iniciando resolución de stream para: "${movie.name}" (ID: ${movie.contentId})',
    );

    // Restaurar tokens de sesión activos si existen en almacenamiento
    await restoreSessionFromStorage();

    // Si no teníamos snField guardado de una sesión previa, vincularlo sin VPN
    if (_currentSnField.isEmpty) {
      MoiamovApiService.logLine(
        '↻ Obteniendo snToken para asociar dispositivo...',
      );
      final fp = await MoiamovApiService._deviceFingerprint();
      final ioClient = HttpClient()
        ..badCertificateCallback = MoiamovApiService._acceptPortalCert;
      _trackClient(ioClient);
      try {
        final sn = await _fetchSnToken(
          ioClient,
          MoiamovApiService.defaultBaseUrl,
          fp,
          const Duration(seconds: 4),
        );
        if (sn != null && sn['_token'] != null) {
          final snToken = sn['_token'].toString();
          _currentSnField = MoiamovApiService._md5Hex(
            '$snToken$kMoiamovSnSalt',
          );
          MoiamovApiService._activeSnField = _currentSnField;
          final prefs = await SharedPreferences.getInstance();
          unawaited(prefs.setString('moiamov_sn_field', _currentSnField));
          unawaited(
            prefs.setString('moiamov_device_mac', MoiamovApiService._deviceMac),
          );
          MoiamovApiService.logLine(
            '✅ snField vinculado con MAC (${MoiamovApiService._deviceMac}): ${MoiamovApiService._short(_currentSnField, 16)}',
          );
        }
      } catch (e) {
        MoiamovApiService.logLine('⚠️ Error obteniendo snToken: $e');
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
      MoiamovApiService.logLine(
        '↻ Intentando reactivación de sesión para VOD...',
      );
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
      MoiamovApiService.logLine(
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
      selectedQuality = MoiamovApiService.pickBestQuality(playInfo.qualities);
    }

    // 3. Selección de Audio (PLAN §3.Paso 2.B)
    final selectedSource = selectedQuality.bestAudioSource;
    if (selectedSource == null) {
      MoiamovApiService.logLine(
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
    MoiamovApiService.logLine(
      '🔊 Pista elegida: ${selectedQuality.quality} - ${selectedSource.audioInfo} (Media ID: ${selectedSource.mediaContentId})',
    );
    MoiamovApiService.logLine(
      '💬 Subtítulos: ${subtitles.isEmpty ? 'ninguno' : subtitles.map((s) => s.language).join(', ')}',
    );

    // 5. Resolución con Titan Ranger (Alternativa B) o getSlbInfo
    String? streamUrl = selectedSource.directUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      MoiamovApiService.logLine(
        '✅ URL directa encontrada en startPlayVOD: ${MoiamovApiService._short(streamUrl, 80)}',
      );
    } else {
      // Intento A: Titan Ranger con libranger-jni.so en Android
      if (TitanRangerService.isSupported) {
        MoiamovApiService.logLine(
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
              app: MoiamovApiService.apkPackage,
              appVer: MoiamovApiService.apkVer,
              userId: _currentUserId,
              devId: MoiamovApiService._deviceMac,
              portalKey: MoiamovApiService.portalKey,
              log: MoiamovApiService.logLine,
            );
            if (prepared.error != null) lastResolutionError = prepared.error;
            if (prepared.playUrl != null) streamUrl = prepared.playUrl;
          }
        } catch (e) {
          MoiamovApiService.logLine(
            '⚠️ [Titan Ranger] Excepción durante resolución nativa: $e',
          );
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
      MoiamovApiService.logLine('❌ No se pudo obtener la URL de streaming');
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
        'PORTAL_KEY': MoiamovApiService.portalKey,
        'apk': MoiamovApiService.apkPackage,
        'apkVer': MoiamovApiService.apkVer,
        'spkgVer': MoiamovApiService.spkgVer,
        if (_currentUserId.isNotEmpty) 'userId': _currentUserId,
        if (_currentUserIdentity.isNotEmpty)
          'userIdentity': _currentUserIdentity,
      },
    );
  }
}
