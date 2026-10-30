import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_search_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

MovieItem movie(
  String id,
  String name, {
  String type = 'movie',
  String? year,
  String? actors,
}) => MovieItem(
  contentId: id,
  name: name,
  programType: type,
  year: year,
  actorDisplay: actors,
);

List<String> names(List<MovieItem> movies) => [for (final m in movies) m.name];

/// Páginas fijas por número; cuenta los pedidos.
class FakeServer {
  final Map<int, List<MovieItem>> pages;
  final int total;
  final List<(String, int)> calls = [];

  FakeServer(this.pages, {required this.total});

  Future<MovieSearchPage?> call(String query, int page) async {
    calls.add((query, page));
    return MovieSearchPage(items: pages[page] ?? const [], total: total);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('cleanSearchPage', () {
    test('deja sólo películas: sin series ni adelantos', () {
      final clean = cleanSearchPage(
        [
          movie('1', 'Batman', year: '1989'),
          movie('2', 'Batman T2', type: 'teleplay'),
          movie('3', 'Batman: Caped Crusader Temp.1', type: 'teleplay'),
          movie('4', '(Tráiler) Batman', type: 'trailer'),
          movie('5', 'Batman Ninja vs. Yakuza League'),
        ],
        'batman',
        {},
      );
      expect(names(clean), ['Batman', 'Batman Ninja vs. Yakuza League']);
    });

    test('saca repetidos por id y por título y año, también entre páginas', () {
      final seen = <String>{};
      final first = cleanSearchPage(
        [
          movie('a', 'Toy Story 4', year: '2019'),
          movie('a', 'Toy Story 4', year: '2019'),
          movie('b', 'Toy Story 4', year: '2019'),
          movie('c', 'Toy Story 3', year: '2010'),
        ],
        'toy story',
        seen,
      );
      final second = cleanSearchPage(
        [movie('c', 'Toy Story 3', year: '2010'), movie('d', 'Toy Story 2')],
        'toy story',
        seen,
      );
      expect(names(first), ['Toy Story 4', 'Toy Story 3']);
      expect(names(second), ['Toy Story 2']);
    });

    test('primero las que tienen todas las palabras en el título', () {
      final clean = cleanSearchPage(
        [
          movie('1', 'La Reyna del Cartel'),
          movie('2', 'Sergio Leone: el italiano que inventó América'),
          movie('3', 'El rey león'),
          movie('4', 'Mufasa: El rey león'),
        ],
        'rey leon',
        {},
      );
      expect(names(clean), [
        'El rey león',
        'Mufasa: El rey león',
        'La Reyna del Cartel',
        'Sergio Leone: el italiano que inventó América',
      ]);
    });
  });

  group('searchLocalMovies', () {
    final catalog = [
      movie('1', 'Troya', actors: 'Brad Pitt,Eric Bana'),
      movie('2', 'Rápidos y furiosos X'),
      movie('3', 'Brad Pitt: todas las caras'),
      movie('4', 'Batman T1', type: 'teleplay'),
    ];

    test('busca en título y actores sin importar tildes', () {
      expect(names(searchLocalMovies(catalog, 'rapidos')), [
        'Rápidos y furiosos X',
      ]);
      expect(names(searchLocalMovies(catalog, 'BRAD pitt')), [
        'Brad Pitt: todas las caras',
        'Troya',
      ]);
    });

    test('pide todas las palabras y no trae series', () {
      expect(searchLocalMovies(catalog, 'brad bana'), hasLength(1));
      expect(searchLocalMovies(catalog, 'batman'), isEmpty);
    });
  });

  group('MovieSearchController', () {
    MovieSearchController controller(
      MovieSearchFetcher fetch, {
      List<MovieItem> local = const [],
    }) {
      final c = MovieSearchController(fetch: fetch, localMovies: () => local);
      addTearDown(c.dispose);
      return c;
    }

    test('con menos de 2 letras no busca y muestra las recientes', () async {
      final server = FakeServer({}, total: 0);
      final c = controller(server.call);
      await c.search(' b ');
      expect(server.calls, isEmpty);
      expect(c.showHistory, isTrue);
    });

    test('si quedan pocas películas pide más páginas, hasta 3', () async {
      final server = FakeServer({
        1: [movie('1', 'Batman'), movie('s1', 'Batman T1', type: 'teleplay')],
        2: [movie('2', 'Batman Returns')],
        3: [movie('3', 'Batman Begins')],
        4: [movie('4', 'Batman Forever')],
      }, total: 200);
      final c = controller(server.call);
      await c.search('batman');
      expect(server.calls.map((call) => call.$2), [1, 2, 3]);
      expect(names(c.results), ['Batman', 'Batman Returns', 'Batman Begins']);
      expect(c.isLoading, isFalse);
      expect(c.canLoadMore, isTrue);
    });

    test('loadMore agrega abajo y se detiene al llegar al total', () async {
      final page1 = [
        for (var i = 0; i < MovieSearchPage.pageSize; i++)
          movie('a$i', 'Toy Story $i'),
      ];
      final server = FakeServer({
        1: page1,
        2: [movie('b', 'Toy Story final')],
      }, total: MovieSearchPage.pageSize + 1);
      final c = controller(server.call);
      await c.search('toy story');
      expect(c.results, hasLength(MovieSearchPage.pageSize));

      await c.loadMore();
      expect(c.results.last.name, 'Toy Story final');
      expect(c.canLoadMore, isFalse);
      await c.loadMore();
      expect(server.calls, hasLength(2));
    });

    test('una respuesta vieja que llega tarde se descarta', () async {
      final pending = <String, Completer<MovieSearchPage?>>{};
      final c = controller((query, page) {
        return (pending[query] = Completer()).future;
      });
      final first = c.search('batman');
      final second = c.search('superman');
      pending['superman']!.complete(
        MovieSearchPage(items: [movie('2', 'Superman')], total: 1),
      );
      await second;
      pending['batman']!.complete(
        MovieSearchPage(items: [movie('1', 'Batman')], total: 1),
      );
      await first;
      expect(c.query, 'superman');
      expect(names(c.results), ['Superman']);
    });

    test('submit no repite la misma búsqueda (ni con otras tildes)', () async {
      final server = FakeServer({
        1: [movie('1', 'El rey león')],
      }, total: 1);
      final c = controller(server.call);
      await c.submit('rey león');
      await c.submit(' Rey Leon ');
      expect(server.calls, [('rey león', 1)]);
      expect(names(c.results), ['El rey león']);

      await c.submit('mufasa');
      expect(server.calls.last, ('mufasa', 1));
    });

    test(
      'submit reintenta con el servidor si la anterior fue sin conexión',
      () async {
        var online = false;
        final c = controller(
          (query, page) async => online
              ? MovieSearchPage(items: [movie('9', 'Troya')], total: 1)
              : null,
          local: [movie('1', 'Troya', actors: 'Brad Pitt')],
        );
        await c.submit('troya');
        expect(c.isOffline, isTrue);
        online = true;
        await c.submit('troya');
        expect(c.isOffline, isFalse);
        expect(c.results.single.contentId, '9');
      },
    );

    test('submit vacío con las recientes a la vista no hace nada', () async {
      final server = FakeServer({}, total: 0);
      final c = controller(server.call);
      await c.submit('');
      expect(server.calls, isEmpty);
      expect(c.showHistory, isTrue);
    });

    test('si el servidor falla busca en el catálogo guardado', () async {
      final c = controller(
        (query, page) async => null,
        local: [movie('1', 'Troya', actors: 'Brad Pitt')],
      );
      await c.search('brad pitt');
      expect(c.isOffline, isTrue);
      expect(names(c.results), ['Troya']);
      expect(c.canLoadMore, isFalse);

      await c.search('troya');
      expect(c.isOffline, isTrue);
    });

    test('apretar Buscar guarda la búsqueda en recientes', () async {
      final server = FakeServer({
        1: [movie('1', 'We Live in Time')],
      }, total: 1);
      final c = controller(server.call);
      await c.submit('we');
      expect(c.history, ['we']);
      // Repetirla no la duplica; la anterior sube al principio.
      await c.submit('rocky');
      await c.submit('We');
      expect(c.history, ['We', 'rocky']);
      expect(await MovieSearchHistory().load(), ['We', 'rocky']);
    });

    test('con menos de 2 letras no se guarda', () async {
      final c = controller(FakeServer({}, total: 0).call);
      await c.submit('w');
      expect(c.history, isEmpty);
    });

    test('abrir una película guarda la búsqueda en recientes', () async {
      final server = FakeServer({
        1: [movie('1', 'Batman')],
      }, total: 1);
      final c = controller(server.call);
      await c.search('batman');
      await c.rememberQuery();
      expect(c.history, ['batman']);

      final reloaded = await MovieSearchHistory().load();
      expect(reloaded, ['batman']);
    });
  });

  group('MovieSearchHistory', () {
    test(
      'la más nueva primero, sin repetidos por tildes ni mayúsculas',
      () async {
        final history = MovieSearchHistory();
        await history.remember('rapidos');
        await history.remember('Batman');
        final entries = await history.remember('Rápidos');
        expect(entries, ['Rápidos', 'Batman']);
      },
    );

    test('guarda hasta 10', () async {
      final history = MovieSearchHistory();
      for (var i = 0; i < 12; i++) {
        await history.remember('busqueda $i');
      }
      expect(history.entries, hasLength(MovieSearchHistory.maxEntries));
      expect(history.entries.first, 'busqueda 11');
    });
  });
}
