import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovieModels & MoiamovApiService', () {
    test('MovieItem and CategoryColumn parse json correctly', () {
      final json = {
        'columnId': 10001,
        'columnName': 'Tendencias',
        'code': 'masnew_featured',
        'assetList': [
          {
            'contentId': '999',
            'name': 'Película de Prueba',
            'score': '8.5',
            'year': '2024',
            'posterList': [
              {'fileType': 'poster', 'fileUrl': 'https://example.com/poster.jpg'}
            ]
          }
        ]
      };

      final cat = CategoryColumn.fromJson(json);
      expect(cat.columnId, 10001);
      expect(cat.columnName, 'Tendencias');
      expect(cat.movies.length, 1);

      final movie = cat.movies.first;
      expect(movie.contentId, '999');
      expect(movie.name, 'Película de Prueba');
      expect(movie.score, '8.5');
      expect(movie.poster, 'https://example.com/poster.jpg');
    });

    test('loadFallbackCatalog loads bundled assets', () async {
      final service = MoiamovApiService.instance;
      final result = await service.loadFallbackCatalog();

      expect(result.categories, isNotEmpty);
      expect(result.totalMovies, greaterThan(0));
      expect(result.isFromNetwork, isFalse);
      expect(result.statusMessage, contains('títulos'));
    });

    test('loadSavedOrBundled prefiere la última descarga guardada', () async {
      final dir = await Directory.systemTemp.createTemp('moai_catalog_');
      final service = MoiamovApiService.instance;
      service.debugSetCatalogDirectory(dir);
      try {
        expect(await service.lastSavedCatalogAt(), isNull);
        final payload = {
          'recommendList': [
            {
              'columnId': 7,
              'columnName': 'Guardado',
              'code': 'masnew_movies',
              'assetList': [
                {'contentId': '1', 'name': 'Desde disco'},
              ],
            },
          ],
        };
        await File('${dir.path}/masnew_movies.json').writeAsString(
          jsonEncode(payload),
        );

        final saved = await service.loadSavedOrBundled(section: 'masnew_movies');
        expect(saved.source, CatalogSource.savedCatalog);
        expect(saved.isHardcoded, isFalse);
        expect(saved.categories.first.movies.first.name, 'Desde disco');

        final missing = await service.loadSavedOrBundled(section: 'masnew_series');
        expect(missing.source, CatalogSource.assetBundle);
        expect(missing.isHardcoded, isTrue);

        final stamp = DateTime(2026, 10, 12, 18, 40);
        await File('${dir.path}/masnew_movies.json').setLastModified(stamp);
        final savedAt = await service.lastSavedCatalogAt();
        expect(savedAt, isNotNull);
        final local = savedAt!.toLocal();
        expect(local.year, 2026);
        expect(local.month, 10);
        expect(local.day, 12);
      } finally {
        service.debugSetCatalogDirectory(null);
        await dir.delete(recursive: true);
      }
    });
  });
}
