import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/models/channel.dart';

Channel _ch(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: '',
      fallbackUrls: ['http://$id.m3u8'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeSearchController', () {
    test('filtra canales por nombre', () {
      final search = HomeSearchController();
      final channels = [
        _ch('1', 'ESPN'),
        _ch('2', 'América'),
      ];

      search.initialize();
      expect(search.results, isEmpty);

      search.updateResults(channels, 'esp');
      expect(search.results.length, 1);
      expect(search.results.first.name, 'ESPN');

      search.updateResults(channels, '');
      expect(search.results, isEmpty);

      search.dispose();
    });

    test('activateAlphabetMode requiere ≥2 resultados y ≥2 letras', () {
      final search = HomeSearchController();
      final channels = [
        _ch('1', 'Alpha TV'),
        _ch('2', 'Zulu TV'),
        _ch('3', 'Beta Radio'),
      ];

      search.updateResults(channels, 'tv');
      expect(search.results.length, 2);
      expect(search.activateAlphabetMode(), isTrue);
      expect(search.isAlphabetMode, isTrue);
      expect(search.alphabetLetters, ['A', 'Z']);

      final idx = search.jumpToLetter('Z');
      expect(idx, 1);
      expect(search.isAlphabetMode, isFalse);

      search.dispose();
    });

    test('activateAlphabetMode falla con un solo resultado', () {
      final search = HomeSearchController();
      search.updateResults([_ch('1', 'ESPN')], 'esp');
      expect(search.results.length, 1);
      expect(search.activateAlphabetMode(), isFalse);
      search.dispose();
    });
  });
}

