import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';

import 'helpers/spanish_translations.dart';

/// Catálogo de Películas con una categoría de tráileres y un tráiler suelto
/// en otra categoría.
Future<Directory> writeMoviesCatalog() async {
  final dir = await Directory.systemTemp.createTemp('moai_catalog_');
  Map<String, dynamic> asset(String id, String name, String type) => {
    'contentId': id,
    'name': name,
    'programType': type,
  };
  await File('${dir.path}/masnew_movies.json').writeAsString(
    jsonEncode({
      'recommendList': [
        {
          'columnId': 1,
          'name': 'Comedia',
          'assetList': [
            asset('m1', 'Coco', 'movie'),
            asset('t1', '(Tráiler)Weapons', 'trailer'),
          ],
        },
        {
          'columnId': 2,
          'name': 'Tráiler',
          'assetList': [
            asset('t1', '(Tráiler)Weapons', 'trailer'),
            asset('t2', '(Tráiler) Superman', 'trailer'),
          ],
        },
      ],
    }),
  );
  return dir;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await writeMoviesCatalog();
    MoiamovApiService.instance.debugSetCatalogDirectory(dir);
  });

  tearDown(() async {
    MoiamovApiService.instance.debugSetCatalogDirectory(null);
    await dir.delete(recursive: true);
  });

  test('los adelantos salen de la grilla y quedan aparte', () async {
    useSpanishTranslations();
    final provider = FeaturedMoviesProvider()
      ..setAvailableSections({FeaturedMoviesProvider.sectionMovies});
    await provider.loadSection(FeaturedMoviesProvider.sectionMovies);

    const section = FeaturedMoviesProvider.sectionMovies;
    final categories = provider.categoriesFor(section);
    // "Tráiler" (ya "Adelantos") queda vacía y desaparece; en Comedia sólo
    // la película.
    expect(categories.map((c) => c.columnName), ['Comedia']);
    expect(categories.single.movies.map((m) => m.name), ['Coco']);
    expect(provider.itemsFor(section).map((m) => m.name), ['Coco']);

    // Cada adelanto una sola vez, en el orden del catálogo.
    expect(provider.trailersFor(section).map((m) => m.contentId), [
      't1',
      't2',
    ]);
  });
}
