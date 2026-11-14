part of '../moiamov_api_service.dart';

/// El catálogo: descarga por secciones, copia en disco, búsqueda y estantes.
extension MoiamovCatalog on MoiamovApiService {
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
    serverUrl ??= _sessionHost ?? MoiamovApiService.defaultBaseUrl;
    final sectionLabel = MoiamovApiService._sectionLabel(section);

    // 1. Descarga en vivo por API directa
    final candidateHosts = <String>{
      serverUrl,
      MoiamovApiService.defaultBaseUrl,
      'https://ftmrmy.jdfey0cd.com',
    }.map(_cleanUrl).toSet().toList();

    final candidateCodes = <String>[section];

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final endpointUri = Uri.parse('$baseUrl/api/portalCore/getNextColumns');

      for (final code in candidateCodes) {
        if (_syncCancelled) {
          return _emptyCatalog(sectionLabel);
        }
        MoiamovApiService.logLine(
          'getNextColumns $sectionLabel: código "$code" → $host',
        );

        final ioClient = HttpClient()
          ..badCertificateCallback = MoiamovApiService._acceptPortalCert
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
          request.headers.set('apk', MoiamovApiService.apkPackage);
          request.headers.set('apkVer', MoiamovApiService.apkVer);
          request.headers.set('spkgVer', MoiamovApiService.spkgVer);
          request.headers.set('PORTAL_KEY', MoiamovApiService.portalKey);

          final queryData = {
            'userToken': userToken ?? _currentUserToken,
            'userId': userId ?? _currentUserId,
            'portalCode': portalCode ?? _currentPortalCode,
            'pageNum': 1,
            'pageSize': 50,
            'columnCode': code,
            'version': '',
          };

          final encryptedBody = MoiamovApiService.encryptPayload(queryData);
          request.write(encryptedBody);

          final response = await request.close().timeout(timeout);
          // Los bytes tal cual: pasarlos a texto también va en el otro hilo.
          // [timeout] corta si deja de llegar (no por lo que tarda en total:
          // por una VPN lenta el catálogo entero puede tardar más), con un
          // tope por si llega a cuentagotas.
          final body = await response
              .timeout(timeout)
              .fold(BytesBuilder(copy: false), (b, chunk) => b..add(chunk))
              .timeout(MoiamovApiService._catalogBodyCap);

          if (response.statusCode != 200) {
            MoiamovApiService.logLine(
              '⚠️ HTTP ${response.statusCode} ($host / $code)',
            );
            continue;
          }

          // El catálogo pesa cientos de KB cifrados en 3DES. Leerlo,
          // descifrarlo, contarlo y guardarlo va todo en otro hilo: acá
          // vuelve sólo un resumen y la pantalla no se traba. La clave y la
          // ruta se leen desde acá (allá no hay .env ni path_provider).
          final key = MoiamovApiService.portalKey;
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
          MoiamovApiService.logLine(
            '↳ returnCode=$returnCode${errMsg != null ? ' ($errMsg)' : ''}',
          );
          if (download.decryptError != null) {
            MoiamovApiService.logLine(
              '⚠️ No se pudo descifrar data del server: ${download.decryptError}',
            );
          }

          if (download.ok) {
            if (download.titles > 0) {
              final total = download.titles;
              final cats = download.categories;
              MoiamovApiService.logLine(
                '✅ EN VIVO: $total títulos en $cats categorías ($sectionLabel)',
              );
              if (download.saved) {
                MoiamovApiService.logLine(
                  'Guardada última descarga de $section.',
                );
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
            MoiamovApiService.logLine(
              '⚠️ Respuesta OK pero sin títulos ($sectionLabel / $code).',
            );
          } else if (returnCode == 'aaa100028') {
            MoiamovApiService.logLine(
              '⚠️ Sesión no válida (aaa100028) en $host',
            );
            if (!_reactivationTried) {
              _reactivationTried = true;
              MoiamovApiService.logLine(
                '↻ Reactivando dispositivo (una sola vez)...',
              );
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
          MoiamovApiService.logLine('⚠️ Error consultando $host ($code): $e');
        } finally {
          _releaseClient(ioClient);
        }

        await Future.delayed(const Duration(milliseconds: 250));
      }
    }

    // Sin respaldos: si no bajó en vivo, la sección queda sin actualizar.
    MoiamovApiService.logLine('⚠️ $sectionLabel no se pudo descargar.');
    return _emptyCatalog(sectionLabel);
  }

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
      '${_cleanUrl(MoiamovApiService.defaultBaseUrl)}/api/portalCore/v3/searchByName',
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
    return MoiamovApiService._readReply(
      body,
      'searchByName',
      MoiamovApiService._searchPageFrom,
    );
  }

  /// Lo de una categoría del catálogo, paginado (`v3/getShelveData`,
  /// SPEC-45 §8): películas o series, sin adelantos; quien lo usa se queda
  /// con lo suyo ([MovieItem.isMovie] / [MovieItem.isSeries]). `columnType`
  /// va `"2"`: con `"movie"` el servidor contesta bien pero vacío. La página 1
  /// empieza con las mismas que la fila del catálogo. Una página corta (menos
  /// de [pageSize]) es la última. `null` si no hay sesión o el pedido falla.
  Future<List<MovieItem>?> fetchShelf(
    int columnId, {
    int page = 1,
    required int pageSize,
    Duration timeout = const Duration(seconds: 6),
  }) => _shelfData(
    columnId,
    page,
    pageSize,
    timeout,
    MoiamovApiService._shelfMoviesFrom,
  );

  /// Cuántas películas tiene la categoría (`assetListTotalSize`); pide una
  /// sola para que la respuesta sea liviana. `null` si falla.
  Future<int?> fetchShelfTotal(
    int columnId, {
    Duration timeout = const Duration(seconds: 6),
  }) => _shelfData(columnId, 1, 1, timeout, MoiamovApiService._shelfTotalFrom);

  /// Detalle de una temporada de una serie (`v4/getItemData`): la ficha, las
  /// otras temporadas y los capítulos. Va con `type: "0"` y `sortType: "0"`:
  /// con "1" (el de la app oficial), "2" o "teleplay" el portal contesta
  /// "节目不存在" (no existe). `null` si no hay sesión o falla.
  Future<SeriesSeasonDetail?> fetchSeriesSeason(
    String contentId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_currentUserToken.isEmpty) return null;
    const type = '0';
    const sortType = '0';
    final body = await _postEncrypted(
      _vodClient,
      '${_cleanUrl(MoiamovApiService.defaultBaseUrl)}/api/portalCore/v4/getItemData',
      {
        'userToken': _currentUserToken,
        'userId': _currentUserId,
        'portalCode': _currentPortalCode,
        'contentId': contentId,
        'type': type,
        'sortType': sortType,
        'language': 'es',
        'macAddr': MoiamovApiService._deviceMac,
      },
      timeout,
    );
    if (body == null) return null;
    return MoiamovApiService._readReply(
      body,
      'getItemData $contentId',
      MoiamovApiService._seriesSeasonFrom,
    );
  }

  /// El id de IMDb de una película ("tt1601913"), que el portal manda en
  /// `keyWords` de su detalle (`v4/getItemData`). Las películas van con
  /// `type: "1"`: con "0" (el de las series) el portal contesta "剧集不存在".
  /// `null` si no hay sesión, falla o no lo trae.
  Future<String?> fetchMovieImdbId(
    String contentId, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_currentUserToken.isEmpty) return null;
    final body = await _postEncrypted(
      _vodClient,
      '${_cleanUrl(MoiamovApiService.defaultBaseUrl)}/api/portalCore/v4/getItemData',
      {
        'userToken': _currentUserToken,
        'userId': _currentUserId,
        'portalCode': _currentPortalCode,
        'contentId': contentId,
        'type': '1',
        'sortType': '0',
        'language': 'es',
        'macAddr': MoiamovApiService._deviceMac,
      },
      timeout,
    );
    if (body == null) return null;
    return MoiamovApiService._readReply(
      body,
      'getItemData $contentId',
      MoiamovApiService._imdbIdFrom,
    );
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
}
