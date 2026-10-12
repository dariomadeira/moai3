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
      final result = await service.loadFallbackCatalog(section: 'masnew_featured');

      expect(result.categories, isNotEmpty);
      expect(result.totalMovies, greaterThan(0));
      expect(result.isFromNetwork, isFalse);
      expect(result.statusMessage, contains('títulos'));
    });
  });
}
