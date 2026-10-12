import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/movie_models.dart';

/// Servicio de sincronización del catálogo de películas y series Xuper Hydra
class XuperApiService {
  static final XuperApiService instance = XuperApiService._internal();

  XuperApiService._internal();

  static const String defaultBaseUrl = 'https://ftmrmy.jdfey0cd.com';
  static const String portalKey = '568e194f-d170-4369-96e8-4a457f641880';
  static const String apkPackage = 'com.xuper.netxxus';
  static const String apkVer = '43404';

  static const String defaultUserId = '967840156';
  static const String defaultUserToken =
      'AXc9dD2RM0bCoY745Nqj17ZpxDVksYpUvKZ9zCvAWDyJnE1_TDiH8hG6Syks1aGw3b5cF_kAtsqCmW-Nit-EgWrigCYhaPV5-URWyAoNH3OvLWZVWkE=';
  static const String defaultPortalCode = '15406';

  CatalogResult? _cachedCatalog;
  CatalogResult? get cachedCatalog => _cachedCatalog;

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

  /// Sincroniza y actualiza el catálogo (features, películas o series)
  /// Intentando primero la API online en vivo y usando fallback local si falla.
  Future<CatalogResult> syncCatalog({
    String section = 'masnew_featured',
    String serverUrl = defaultBaseUrl,
    String userToken = defaultUserToken,
    String userId = defaultUserId,
    String portalCode = defaultPortalCode,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final sectionLabel = section == 'masnew_featured'
        ? 'Destacados'
        : (section == 'masnew_series' ? 'Series' : 'Películas');

    // Lista de dominios de producción conocidos
    final candidateHosts = [
      serverUrl,
      'https://ftmrmy.jdfey0cd.com',
      'https://fuxok.nguvmqhpk.com',
      'https://mptec.dhkrxuzcy.com',
    ].toSet().toList();

    for (final host in candidateHosts) {
      final baseUrl = _cleanUrl(host);
      final endpointUri = Uri.parse('$baseUrl/api/portalCore/getNextColumns');
      debugPrint('🌐 [SYNC $sectionLabel] Conectando a $endpointUri...');

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
        request.headers.set('spkgVer', '1.1.4');
        request.headers.set('PORTAL_KEY', portalKey);

        final requestPayload = jsonEncode({
          'userToken': userToken,
          'userId': userId,
          'portalCode': portalCode,
          'pageNum': 1,
          'pageSize': 50,
          'columnCode': section,
          'version': '',
        });

        request.write(requestPayload);
        final response = await request.close().timeout(timeout);
        final responseBody = await response.transform(utf8.decoder).join().timeout(timeout);

        debugPrint('🌐 [SYNC] HTTP ${response.statusCode} desde $host: ${responseBody.length > 200 ? responseBody.substring(0, 200) : responseBody}');

        if (response.statusCode == 200) {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map<String, dynamic>) {
            // Verificar si el backend devolvió error de región o versión
            final returnCode = decoded['returnCode']?.toString();
            if (returnCode != null && returnCode != '0' && returnCode != '0000' && returnCode != '200') {
              debugPrint('⚠️ [SYNC] Backend respondió código no exitoso: $returnCode (${decoded['errorMessage']})');
              continue;
            }

            final innerData = decoded['data'];
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
                debugPrint('✅ [SYNC ONLINE] $total títulos en ${list.length} categorías sincronizadas.');
                final result = CatalogResult(
                  categories: list,
                  isFromNetwork: true,
                  statusMessage:
                      '$sectionLabel sincronizados en vivo ($total títulos en ${list.length} categorías)',
                );
                _cachedCatalog = result;
                return result;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [SYNC] Error consultando $host: $e');
      } finally {
        ioClient.close();
      }
    }

    // 2. Si falló la red en todos los dominios, cargar copia local de respaldo
    return loadFallbackCatalog(section: section);
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
        debugPrint('📦 [SYNC LOCAL] $total títulos de respaldo cargados.');
        final result = CatalogResult(
          categories: list,
          isFromNetwork: false,
          statusMessage:
              '$sectionLabel locales cargados ($total títulos en ${list.length} categorías)',
        );
        _cachedCatalog ??= result;
        return result;
      }
    } catch (e) {
      debugPrint('❌ [SYNC ERROR] Error al cargar assets/data/$section.json: $e');
    }

    return CatalogResult(
      categories: [],
      isFromNetwork: false,
      statusMessage: 'No se pudo cargar el catálogo de $sectionLabel.',
    );
  }
}
