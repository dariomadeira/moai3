import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_grid_catalog.dart';

MovieItem m(String id) => MovieItem(contentId: id, name: 'Película $id');

CategoryColumn cat(int id, List<String> ids) => CategoryColumn(
  columnId: id,
  columnName: 'Categoría $id',
  movies: [for (final i in ids) m(i)],
);

List<String> ids(CategoryColumn c) => [for (final x in c.movies) x.contentId];

List<String> range(String prefix, int from, int to) => [
  for (var i = from; i <= to; i++) '$prefix$i',
];

void main() {
  group('build', () {
    test('sin repetidas ni extras queda igual', () {
      final out = MovieGridCatalog.build([
        cat(1, range('a', 1, 10)),
        cat(2, range('b', 1, 10)),
      ]);
      expect(out.map(ids), [range('a', 1, 10), range('b', 1, 10)]);
    });

    test(
      'la repetida queda en la primera categoría y la otra completa con extras',
      () {
        final out = MovieGridCatalog.build(
          [
            cat(1, range('a', 1, 10)),
            cat(2, ['a3', ...range('b', 1, 9)]),
          ],
          extras: {
            // La página 1 del servidor empieza con las mismas 10.
            2: ['a3', ...range('b', 1, 9), 'b10', 'b11'].map(m).toList(),
          },
        );
        expect(ids(out[0]), range('a', 1, 10));
        expect(ids(out[1]), range('b', 1, 10));
      },
    );

    test('ninguna película aparece dos veces en toda la grilla', () {
      final out = MovieGridCatalog.build(
        [
          cat(1, range('x', 1, 10)),
          cat(2, range('x', 5, 14)),
          cat(3, range('x', 1, 10)),
        ],
        extras: {
          2: range('x', 5, 30).map(m).toList(),
          3: range('x', 1, 40).map(m).toList(),
        },
      );
      final all = [for (final c in out) ...ids(c)];
      expect(all.toSet().length, all.length);
      expect(out.map((c) => c.movies.length), [10, 10, 10]);
    });

    test('sin extras se recorta a filas completas de 5', () {
      final out = MovieGridCatalog.build([
        cat(1, range('a', 1, 10)),
        // Pierde 3 por repetidas: quedan 7 → se muestran 5.
        cat(2, ['a1', 'a2', 'a3', ...range('b', 1, 7)]),
      ]);
      expect(ids(out[1]), range('b', 1, 5));
    });

    test('lo recortado puede aparecer en una categoría de más abajo', () {
      final out = MovieGridCatalog.build([
        cat(1, range('a', 1, 10)),
        cat(2, ['a1', 'a2', 'a3', ...range('b', 1, 7)]),
        cat(3, ['b6', 'b7', ...range('c', 1, 8)]),
      ]);
      expect(ids(out[1]), range('b', 1, 5));
      expect(ids(out[2]), ['b6', 'b7', ...range('c', 1, 8)]);
    });

    test('con menos de 5 queda como está; vacía se saca', () {
      final out = MovieGridCatalog.build([
        cat(1, range('a', 1, 10)),
        cat(2, ['a1', 'n1', 'n2', 'n3']),
        cat(3, ['a2', 'a3']),
      ]);
      expect(out.map((c) => c.columnId), [1, 2]);
      expect(ids(out[1]), ['n1', 'n2', 'n3']);
    });

    test('las repetidas dentro de la misma lista no se duplican', () {
      final out = MovieGridCatalog.build(
        [cat(1, range('a', 1, 5))],
        extras: {
          1: [
            ...range('a', 1, 5),
            'a5',
            'a6',
            ...range('a', 7, 12),
          ].map(m).toList(),
        },
      );
      expect(ids(out[0]), range('a', 1, 10));
    });

    test('sin contentId compara por nombre y póster', () {
      final sinId = MovieItem(contentId: '', name: 'Igual', poster: 'p.jpg');
      final out = MovieGridCatalog.build([
        CategoryColumn(
          columnId: 1,
          columnName: 'A',
          movies: [sinId, ...range('a', 1, 4).map(m)],
        ),
        CategoryColumn(
          columnId: 2,
          columnName: 'B',
          movies: [sinId, ...range('b', 1, 5).map(m)],
        ),
      ]);
      expect(out[1].movies.any((x) => x.contentId.isEmpty), isFalse);
    });

    test('conserva columnId, nombre y code', () {
      final out = MovieGridCatalog.build([
        CategoryColumn(
          columnId: 7,
          columnName: 'Acción',
          code: 'abc',
          movies: range('a', 1, 5).map(m).toList(),
        ),
      ]);
      expect(
        (out.single.columnId, out.single.columnName, out.single.code),
        (7, 'Acción', 'abc'),
      );
    });
  });

  group('build con "Ver todas"', () {
    test(
      '9 películas + la tarjeta; la fila de TMDb sigue con 10 sin tarjeta',
      () {
        final out = MovieGridCatalog.build(
          [cat(88888, range('t', 1, 10)), cat(1, range('a', 1, 10))],
          withShowAll: {1},
        );
        expect((out[0].movies.length, out[0].hasMore), (10, false));
        expect(ids(out[1]), range('a', 1, 9));
        expect(out[1].hasMore, isTrue);
      },
    );

    test('la décima que no entra puede aparecer más abajo', () {
      final out = MovieGridCatalog.build(
        [
          cat(1, range('a', 1, 10)),
          cat(2, ['a10', ...range('b', 1, 9)]),
        ],
        withShowAll: {1, 2},
      );
      expect(ids(out[1]), ['a10', ...range('b', 1, 8)]);
    });

    test('si queda corta, recorta a 4 + la tarjeta (una fila completa)', () {
      final out = MovieGridCatalog.build(
        [
          cat(1, range('a', 1, 10)),
          cat(2, [...range('a', 1, 4), ...range('b', 1, 6)]),
        ],
        withShowAll: {1, 2},
      );
      expect(ids(out[1]), range('b', 1, 4));
      expect(out[1].movies.length + 1, 5);
    });

    test('con menos de 5 casilleros queda como está, con la tarjeta', () {
      final out = MovieGridCatalog.build(
        [
          cat(1, range('a', 1, 10)),
          cat(2, [...range('a', 1, 8), 'b1', 'b2']),
        ],
        withShowAll: {1, 2},
      );
      // a9 ya está en la primera: quedan las dos propias + la tarjeta.
      expect(ids(out[1]), ['b1', 'b2']);
      expect(out[1].hasMore, isTrue);
    });

    test('columnsNeedingMore busca 9 en las que llevan la tarjeta', () {
      final needing = MovieGridCatalog.columnsNeedingMore(
        [cat(1, range('a', 1, 9)), cat(2, range('b', 1, 9))],
        fetchable: {1, 2},
        withShowAll: {1},
      );
      expect(needing, {2});
    });
  });

  group('topRated', () {
    MovieItem s(String id, String? score, {String type = 'movie'}) => MovieItem(
      contentId: id,
      name: 'Película $id',
      score: score,
      programType: type,
    );

    test(
      'las de más de 7, de mayor a menor; empate en el orden del catálogo',
      () {
        final row = MovieGridCatalog.topRated([
          s('a', '7.5'),
          s('b', '8.6'),
          s('c', '7.0'),
          s('d', '9.1'),
          s('e', '7.5'),
          s('f', null),
          s('g', '0'),
        ], name: 'Mejor puntuadas')!;
        expect(ids(row), ['d', 'b', 'a', 'e']);
        expect(row.columnId, MovieGridCatalog.topRatedColumnId);
        expect(row.columnName, 'Mejor puntuadas');
        expect(row.hasMore, isFalse);
      },
    );

    test('sin series, adelantos ni repetidas', () {
      final row = MovieGridCatalog.topRated([
        s('a', '8.0'),
        s('a', '8.0'),
        s('t', '9.0', type: 'trailer'),
        s('s', '9.0', type: 'teleplay'),
      ], name: 'x')!;
      expect(ids(row), ['a']);
    });

    test('ninguna buena: sin fila', () {
      expect(MovieGridCatalog.topRated([s('a', '6.9')], name: 'x'), isNull);
    });
  });

  group('columnsNeedingMore', () {
    test('marca las que pierden películas o traen menos de 10', () {
      final needing = MovieGridCatalog.columnsNeedingMore(
        [
          cat(1, range('a', 1, 10)),
          cat(2, ['a1', ...range('b', 1, 9)]),
          cat(3, range('c', 1, 10)),
          cat(4, range('d', 1, 6)),
        ],
        fetchable: {1, 2, 3, 4},
      );
      expect(needing, {2, 4});
    });

    test('no pide más para las que no son del servidor (fila de TMDb)', () {
      final needing = MovieGridCatalog.columnsNeedingMore(
        [
          cat(88888, range('a', 1, 3)),
          cat(2, ['a1', ...range('b', 1, 9)]),
        ],
        fetchable: {2},
      );
      expect(needing, {2});
    });
  });
}
