import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/series_anime_filter.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

MovieItem serie(String id, {String tags = 'Drama', String type = 'teleplay'}) =>
    MovieItem(
      contentId: id,
      name: 'Serie $id T1',
      tags: tags,
      programType: type,
    );

SeriesSeasonDetail detail(String id, String? country) => SeriesSeasonDetail(
  info: serie(id),
  seasons: const [],
  episodes: const [],
  originalCountry: country,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final filter = SeriesAnimeFilter.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    filter.resetForTest();
  });

  tearDown(filter.resetForTest);

  group('SeriesAnimeFilter', () {
    test('apagado no oculta nada', () {
      expect(filter.hides(serie('a', tags: 'Animation')), isFalse);
    });

    test('oculta la animada de Japón, China o Corea; no la de otro país, ni '
        'la que no es animada, ni una película', () async {
      filter.enabled = true;
      final countries = {
        'jp': 'Japan',
        'kr': 'South Korea',
        'cn': 'China',
        'us': 'United States of America',
        'nd': null,
      };
      final asked = <String>[];
      await filter.resolve(
        [for (final id in countries.keys) serie(id, tags: 'Animation, Comedy')],
        fetchSeason: (id) async {
          asked.add(id);
          return detail(id, countries[id]);
        },
      );
      expect(asked, countries.keys.toList());
      bool hidden(String id) => filter.hides(serie(id, tags: 'Animation'));
      expect(
        [for (final id in countries.keys) hidden(id)],
        [true, true, true, false, false],
      );
      expect(filter.hides(serie('jp')), isFalse);
      final movie = MovieItem(
        contentId: 'x',
        name: 'Película x',
        tags: 'Animation',
        programType: 'movie',
      );
      expect(filter.hides(movie), isFalse);
    });

    test(
      'la animada sin país conocido queda oculta; "Anime" no se pregunta',
      () async {
        filter.enabled = true;
        expect(filter.hides(serie('a', tags: 'Animation')), isTrue);
        expect(filter.pending([serie('b', tags: 'Anime')]), isEmpty);
        expect(filter.hides(serie('b', tags: 'Anime')), isTrue);
      },
    );

    test('el país se pide una vez por serie (todas sus temporadas), se '
        'guarda y lo que no contestó se vuelve a pedir', () async {
      filter.enabled = true;
      final asked = <String>[];
      Future<SeriesSeasonDetail?> fetch(String id) async {
        asked.add(id);
        return id == 'b' ? null : detail(id, 'Japan');
      }

      final items = [
        serie('a', tags: 'Animation'),
        MovieItem(
          contentId: 'a2',
          name: 'Serie a T2',
          tags: 'Animation',
          programType: 'teleplay',
        ),
        serie('b', tags: 'Animation'),
      ];
      await filter.resolve(items, fetchSeason: fetch);
      expect(asked, ['a', 'b']);
      await filter.resolve(items, fetchSeason: fetch);
      expect(asked, ['a', 'b', 'b']);

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('series_origin_v1')!), {
        'serie a': 'Japan',
      });
    });
  });

  group('Ajuste', () {
    test(
      'apagado por defecto; prenderlo activa el filtro y se recuerda',
      () async {
        final prefs = await AppPreferences.init();
        final settings = TvSettingsProvider(prefs);
        expect(settings.hideSeriesAnime, isFalse);
        expect(filter.enabled, isFalse);

        await settings.setHideSeriesAnime(true);
        expect(filter.enabled, isTrue);

        filter.enabled = false;
        expect(TvSettingsProvider(prefs).hideSeriesAnime, isTrue);
        expect(filter.enabled, isTrue);
      },
    );
  });

  group('Grilla de Series', () {
    late Directory dir;

    setUp(() async {
      useSpanishTranslations();
      dir = await Directory.systemTemp.createTemp('moai_anime_');
      MoiamovApiService.instance.debugSetCatalogDirectory(dir);
      Map<String, dynamic> asset(String id, String tags) => {
        'contentId': id,
        'name': 'Serie $id T1',
        'programType': 'teleplay',
        'tags': tags,
      };
      await File('${dir.path}/masnew_series.json').writeAsString(
        jsonEncode({
          'recommendList': [
            {
              'columnId': 40,
              'name': 'Animadas',
              'assetList': [asset('jp', 'Animation'), asset('us', 'Animation')],
            },
            {
              'columnId': 50,
              'name': 'Anime',
              'assetList': [asset('kr', 'Animation')],
            },
            {
              'columnId': 60,
              'name': 'Drama',
              'assetList': [asset('d1', 'Drama')],
            },
          ],
        }),
      );
    });

    tearDown(() async {
      MoiamovApiService.instance.debugSetCatalogDirectory(null);
      await dir.delete(recursive: true);
    });

    test('sin el anime y sin las categorías que quedan vacías; al apagar '
        'vuelve todo', () async {
      const series = FeaturedMoviesProvider.sectionSeries;
      const countries = {'jp': 'Japan', 'us': 'United States', 'kr': 'Korea'};
      filter
        ..debugFetchSeason = ((id) async => detail(id, countries[id]))
        ..enabled = true;
      final provider = FeaturedMoviesProvider(fetchShelf: (_, _) async => null)
        ..setAvailableSections({series});
      await provider.loadSection(series);
      await pumpEventQueue();

      List<List<String>> rows() => [
        for (final c in provider.categoriesFor(series))
          [c.columnName, for (final m in c.movies) m.contentId],
      ];
      expect(rows(), [
        ['Animadas', 'us'],
        ['Drama', 'd1'],
      ]);
      expect([
        for (final m in provider.itemsFor(series)) m.contentId,
      ], isNot(contains('jp')));

      filter.enabled = false;
      expect(rows(), [
        ['Animadas', 'jp', 'us'],
        ['Anime', 'kr'],
        ['Drama', 'd1'],
      ]);
      provider.dispose();
    });
  });
}
