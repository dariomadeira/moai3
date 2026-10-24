import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    test('el catálogo guardado y su fecha', () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('moai_catalog_');
      final service = MoiamovApiService.instance;
      service.debugSetCatalogDirectory(dir);
      try {
        expect(await service.lastSavedCatalogAt(), isNull);
        expect(await service.savedSections(), isEmpty);
        expect(await service.loadPersistedCatalog('masnew_movies'), isNull);

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

        final saved = await service.loadPersistedCatalog('masnew_movies');
        expect(saved, isNotNull);
        expect(saved!.source, CatalogSource.savedCatalog);
        expect(saved.categories.first.movies.first.name, 'Desde disco');
        expect(await service.savedSections(), {'masnew_movies'});

        // La fecha no sale de los archivos: solo se guarda explícitamente.
        expect(await service.lastSavedCatalogAt(), isNull);
        final stamp = DateTime(2026, 10, 12, 18, 40);
        await service.saveCatalogDate(stamp);
        expect(await service.lastSavedCatalogAt(), stamp);
      } finally {
        service.debugSetCatalogDirectory(null);
        await dir.delete(recursive: true);
      }
    });
  });
}
