import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';

import 'helpers/spanish_translations.dart';

const section = FeaturedMoviesProvider.sectionMovies;

List<String> range(String prefix, int from, int to) => [
  for (var i = from; i <= to; i++) '$prefix$i',
];

Map<String, dynamic> column(int id, String name, List<String> ids) => {
  'columnId': id,
  'name': name,
  'assetList': [
    for (final i in ids)
      {'contentId': i, 'name': 'Película $i', 'programType': 'movie'},
  ],
};

/// Acción y Comedia comparten 3 películas, como en el catálogo real.
Future<Directory> writeCatalog() async {
  final dir = await Directory.systemTemp.createTemp('moai_grid_');
  await File('${dir.path}/masnew_movies.json').writeAsString(
    jsonEncode({
      'recommendList': [
        column(10, 'Acción', range('a', 1, 10)),
        column(20, 'Comedia', ['a2', 'a5', 'a9', ...range('c', 1, 7)]),
        column(30, 'Drama', range('d', 1, 10)),
      ],
    }),
  );
  return dir;
}

/// Página 1 del servidor: empieza con las mismas 10 de la fila y sigue.
List<MovieItem> shelfPage(List<String> ids) => [
  for (final i in ids)
    MovieItem(contentId: i, name: 'Película $i', programType: 'movie'),
];

List<List<String>> grid(FeaturedMoviesProvider p) => [
  for (final c in p.categoriesFor(section))
    [for (final m in c.movies) m.contentId],
];

void main() {
  late Directory dir;

  setUp(() async {
    useSpanishTranslations();
    dir = await writeCatalog();
    MoiamovApiService.instance.debugSetCatalogDirectory(dir);
  });

  tearDown(() async {
    MoiamovApiService.instance.debugSetCatalogDirectory(null);
    await dir.delete(recursive: true);
  });

  test(
    'completa la categoría que perdió repetidas con su lista del servidor',
    () async {
      final asked = <int>[];
      final provider = FeaturedMoviesProvider(
        fetchShelf: (id, page) async {
          asked.add(id);
          expect(page, 1);
          if (id == 20) {
            return shelfPage(['a2', 'a5', 'a9', ...range('c', 1, 20)]);
          }
          return null;
        },
      )..setAvailableSections({section});
      await provider.loadSection(section);

      // Sólo Comedia perdía películas: es la única que se pide.
      expect(asked, [20]);
      final rows = grid(provider);
      // Las del servidor muestran 9 + "Ver todas".
      expect(rows[0], range('a', 1, 9));
      expect(rows[1], range('c', 1, 9));
      expect(rows[2], range('d', 1, 9));
      final all = [for (final r in rows) ...r];
      expect(all.toSet().length, all.length);
    },
  );

  test(
    'si el servidor falla, saca las repetidas y deja filas completas',
    () async {
      final provider = FeaturedMoviesProvider(fetchShelf: (_, _) async => null)
        ..setAvailableSections({section});
      await provider.loadSection(section);

      // Comedia: 7 propias + la tarjeta → 4 + la tarjeta (una fila).
      expect(grid(provider)[1], range('c', 1, 4));
    },
  );

  test('un pedido con error no rompe la carga', () async {
    final provider = FeaturedMoviesProvider(
      fetchShelf: (_, _) => Future.error(const SocketException('sin red')),
    )..setAvailableSections({section});
    await provider.loadSection(section);
    expect(grid(provider)[1], range('c', 1, 4));
    expect(provider.errorMessageFor(section), isNull);
  });

  test('no espera más que el tope: lo que no llegó se recorta', () async {
    final never = Completer<List<MovieItem>?>();
    final provider = FeaturedMoviesProvider(
      fetchShelf: (_, _) => never.future,
      shelfWait: const Duration(milliseconds: 200),
    )..setAvailableSections({section});
    final watch = Stopwatch()..start();
    await provider.loadSection(section);
    expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(grid(provider)[1], range('c', 1, 4));
  });

  test(
    'lo que ya bajó se reusa en la sesión y un catálogo nuevo lo descarta',
    () async {
      var calls = 0;
      final provider = FeaturedMoviesProvider(
        fetchShelf: (id, page) async {
          calls++;
          return shelfPage(['a2', 'a5', 'a9', ...range('c', 1, 20)]);
        },
      )..setAvailableSections({section});
      await provider.loadSection(section);
      await provider.loadSection(section, force: true);
      expect(calls, 1);

      provider.setAvailableSections({section});
      await provider.loadSection(section);
      expect(calls, 2);
    },
  );

  test(
    'las películas y adelantos se publican sin esperar a la grilla',
    () async {
      final slow = Completer<List<MovieItem>?>();
      final provider = FeaturedMoviesProvider(fetchShelf: (_, _) => slow.future)
        ..setAvailableSections({section});
      var notified = 0;
      provider.addListener(() => notified++);

      final loading = provider.loadSection(section);
      // Esperar a que la carga lea el disco y quede esperando al servidor.
      while (provider.itemsFor(section).isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(provider.isLoadingFor(section), isTrue);
      expect(provider.categoriesFor(section), isEmpty);
      expect(notified, greaterThanOrEqualTo(2));

      slow.complete(null);
      await loading;
      expect(provider.categoriesFor(section), isNotEmpty);
    },
  );

  group('Mejor puntuadas', () {
    // Acción trae dos buenas (a2: 8.5, a7: 9.0); Drama, una (d1: 7.5).
    setUp(() async {
      Map<String, dynamic> scored(String id, String score) => {
        'contentId': id,
        'name': 'Película $id',
        'programType': 'movie',
        'score': score,
      };
      await File('${dir.path}/masnew_movies.json').writeAsString(
        jsonEncode({
          'recommendList': [
            {
              'columnId': 10,
              'name': 'Acción',
              'assetList': [
                for (final i in range('a', 1, 10))
                  scored(i, i == 'a2' ? '8.5' : (i == 'a7' ? '9.0' : '6.0')),
              ],
            },
            {
              'columnId': 30,
              'name': 'Drama',
              'assetList': [
                for (final i in range('d', 1, 10))
                  scored(i, i == 'd1' ? '7.5' : '5.0'),
              ],
            },
          ],
        }),
      );
    });

    test('va arriba, sin "Ver todas", y sus películas no se repiten', () async {
      final provider = FeaturedMoviesProvider(
        fetchShelf: (id, page) async =>
            id == 10 ? shelfPage([...range('a', 1, 10), 'a11', 'a12']) : null,
      )..setAvailableSections({section});
      await provider.loadSection(section);

      final cats = provider.categoriesFor(section);
      expect(cats.first.columnName, 'Mejor puntuadas');
      expect(cats.first.hasMore, isFalse);
      // 3 buenas → menos de 5: quedan las 3, de mayor a menor.
      expect(grid(provider)[0], ['a7', 'a2', 'd1']);
      // Acción las pierde y completa del servidor (9 + "Ver todas").
      expect(grid(provider)[1], [
        'a1',
        'a3',
        'a4',
        'a5',
        'a6',
        'a8',
        'a9',
        'a10',
        'a11',
      ]);
      final all = [for (final r in grid(provider)) ...r];
      expect(all.toSet().length, all.length);
    });
  });

  group('total de la biblioteca', () {
    // El catálogo trae "All" (se muestra "Todos"): de ahí sale el total.
    setUp(() async {
      await File('${dir.path}/masnew_movies.json').writeAsString(
        jsonEncode({
          'recommendList': [
            column(10, 'Acción', range('a', 1, 10)),
            column(76263, 'All', range('t', 1, 10)),
          ],
        }),
      );
    });

    test('pedido antes de cargar Películas, llega igual (una vez)', () async {
      final asked = <int>[];
      final provider = FeaturedMoviesProvider(
        fetchShelf: (_, _) async => null,
        fetchShelfTotal: (id) async {
          asked.add(id);
          return 31419;
        },
      )..setAvailableSections({section});

      await provider.loadLibraryTotal();
      expect(provider.libraryTotalLoading, isTrue);
      while (provider.libraryTotal == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(provider.libraryTotal, 31419);
      expect(asked, [76263]);

      await provider.loadLibraryTotal();
      expect(asked, [76263]);
      expect(provider.libraryTotalLoading, isFalse);
    });

    test('sin Películas disponibles no pide nada', () async {
      var calls = 0;
      final provider = FeaturedMoviesProvider(
        fetchShelf: (_, _) async => null,
        fetchShelfTotal: (_) async {
          calls++;
          return 1;
        },
      )..setAvailableSections(const {});
      await provider.loadLibraryTotal();
      expect(calls, 0);
      expect(provider.libraryTotal, isNull);
    });

    test('un catálogo nuevo olvida el total', () async {
      final provider = FeaturedMoviesProvider(
        fetchShelf: (_, _) async => null,
        fetchShelfTotal: (_) async => 100,
      )..setAvailableSections({section});
      await provider.loadSection(section);
      await provider.loadLibraryTotal();
      expect(provider.libraryTotal, 100);
      provider.setAvailableSections({section});
      expect(provider.libraryTotal, isNull);
    });
  });

  group('con Comedia toda repetida', () {
    // Acción y Drama primero; Comedia trae sólo películas de ellas.
    setUp(() async {
      await File('${dir.path}/masnew_movies.json').writeAsString(
        jsonEncode({
          'recommendList': [
            column(10, 'Acción', range('a', 1, 10)),
            column(30, 'Drama', range('d', 1, 10)),
            column(20, 'Comedia', [...range('a', 1, 5), ...range('d', 1, 5)]),
          ],
        }),
      );
    });

    /// 30 películas, todas ya vistas arriba: una página "llena" que no suma.
    final seenPage = [
      ...range('a', 1, 10),
      ...range('d', 1, 10),
      ...range('a', 1, 10),
    ];

    test('si la página 1 no alcanza, pide la 2', () async {
      final asked = <(int, int)>[];
      final provider = FeaturedMoviesProvider(
        fetchShelf: (id, page) async {
          asked.add((id, page));
          return shelfPage(page == 1 ? seenPage : range('c', 1, 12));
        },
      )..setAvailableSections({section});
      await provider.loadSection(section);

      expect(asked, [(20, 1), (20, 2)]);
      // a10 y d10 no entran arriba (9 + "Ver todas"): las toma Comedia.
      expect(grid(provider)[2], ['a10', 'd10', ...range('c', 1, 7)]);
    });

    test('se detiene a las 3 páginas aunque no complete', () async {
      final asked = <int>[];
      final provider = FeaturedMoviesProvider(
        fetchShelf: (id, page) async {
          asked.add(page);
          return shelfPage(seenPage);
        },
      )..setAvailableSections({section});
      await provider.loadSection(section);

      expect(asked, [1, 2, 3]);
      // Sólo le quedan las dos que no entraron arriba, más "Ver todas".
      expect(grid(provider)[2], ['a10', 'd10']);
      expect(provider.categoriesFor(section)[2].hasMore, isTrue);
    });
  });
}
