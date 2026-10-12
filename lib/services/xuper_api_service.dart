import 'dart:convert';
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

    // 1. Intentar actualizar online desde endpoint getNextColumns
    try {
      final baseUrl = _cleanUrl(serverUrl);
      final endpoint = Uri.parse('$baseUrl/api/portalCore/getNextColumns');
      debugPrint('🌐 [SYNC $sectionLabel] Conectando a $endpoint...');

      final headers = {
        'Content-Type': 'application/json;charset=utf-8',
        'ProcessResult': 'false',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10; TV) Mobile Safari/537.36',
        'apk': apkPackage,
        'apkVer': apkVer,
        'spkgVer': '1.1.4',
        'PORTAL_KEY': portalKey,
      };

      final body = jsonEncode({
        'userToken': userToken,
        'userId': userId,
        'portalCode': portalCode,
        'pageNum': 1,
        'pageSize': 50,
        'columnCode': section,
        'version': '',
      });

      final response = await http
          .post(endpoint, headers: headers, body: body)
          .timeout(timeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
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
      debugPrint('⚠️ [SYNC] Servidor online no respondió en este intento: $e');
    }

    // 2. Si falló la red, cargar copia local de respaldo
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
