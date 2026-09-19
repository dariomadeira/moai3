import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/models/channel.dart';

void main() {
  group('HomeSearchController memoria', () {
    test('query vacía o corta no crea resultados', () {
      final search = HomeSearchController();
      final channels = List.generate(
        500,
        (i) => Channel(
          id: '$i',
          name: 'Canal $i',
          logoUrl: '',
          fallbackUrls: ['http://x.m3u8'],
          country: 'AR',
          category: 'X',
        ),
      );

      search.initialize();
      expect(search.results, isEmpty);

      search.updateResults(channels, '');
      expect(search.results, isEmpty);

      search.updateResults(channels, 'a');
      expect(search.results, isEmpty);

      search.dispose();
    });

    test('query válida filtra y limita resultados', () {
      final search = HomeSearchController();
      final channels = List.generate(
        150,
        (i) => Channel(
          id: '$i',
          name: 'Canal $i',
          logoUrl: '',
          fallbackUrls: ['http://x.m3u8'],
          country: 'AR',
          category: 'X',
        ),
      );

      search.updateResults(channels, 'canal');
      expect(search.results.length, HomeSearchController.maxResults);
      expect(search.resultsCapped, isTrue);

      search.dispose();
    });
  });
}

