import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_synopsis_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> found(String overview, {bool tv = false}) => {
    tv ? 'tv_results' : 'movie_results': [
      {'id': 1, 'overview': overview},
    ],
  };

  test('needsLookup: vacía, de relleno o en inglés', () {
    const needs = MovieSynopsisService.needsLookup;
    expect(needs(null), isTrue);
    expect(needs('  '), isTrue);
    expect(needs('Sem dados de descrição'), isTrue);
    expect(
      needs(
        'A group of friends join a guide for a trek into the Bolivian '
        'jungle, searching for an Indian village.',
      ),
      isTrue,
    );
    expect(
      needs(
        'En el Ártico, la temperatura puede bajar hasta -70° C. En este '
        'desierto helado, un hombre lucha por sobrevivir.',
      ),
      isFalse,
    );
    // Un título en inglés dentro de un texto en español no la cambia.
    expect(
      needs('Sigue a un mensajero de The Company que entrega un paquete.'),
      isFalse,
    );
  });

  test('pide latino y, si no hay, de España; lo guarda', () async {
    final asked = <String>[];
    final service = MovieSynopsisService(
      fetchImdbId: (_) async => null,
      fetchJson: (path, query) async {
        asked.add('$path ${query['language']}');
        return query['language'] == 'es-ES'
            ? found('Una casa en Madrid.')
            : found('');
      },
    );
    expect(await service.byImdbId('tt1'), 'Una casa en Madrid.');
    expect(asked, ['/find/tt1 es-MX', '/find/tt1 es-ES']);

    // Otra instancia (otro arranque): sale de lo guardado, sin pedir.
    final again = MovieSynopsisService(
      fetchImdbId: (_) async => null,
      fetchJson: (_, _) async => fail('no debía pedir'),
    );
    expect(await again.byImdbId('tt1'), 'Una casa en Madrid.');
  });

  test('sin español: inglés sólo si el catálogo no trae ninguna', () async {
    final asked = <String>[];
    MovieSynopsisService make() => MovieSynopsisService(
      fetchImdbId: (_) async => null,
      fetchJson: (path, query) async {
        asked.add(query['language']!);
        return query['language'] == 'en-US' ? found('A house.') : found('');
      },
    );
    expect(await make().byImdbId('tt2'), isNull);
    expect(asked, ['es-MX', 'es-ES']);
    // "No hay" también se guarda: no se vuelve a pedir.
    asked.clear();
    expect(await make().byImdbId('tt2'), isNull);
    expect(asked, isEmpty);

    expect(await make().byImdbId('tt2', allowEnglish: true), 'A house.');
    expect(asked, ['es-MX', 'es-ES', 'en-US']);
  });

  test('si TMDb no contesta no se guarda nada y se reintenta', () async {
    var answers = false;
    var calls = 0;
    final service = MovieSynopsisService(
      fetchImdbId: (_) async => null,
      fetchJson: (_, _) async {
        calls++;
        return answers ? found('Una serie.', tv: true) : null;
      },
    );
    expect(await service.byImdbId('tt3'), isNull);
    answers = true;
    expect(await service.byImdbId('tt3'), 'Una serie.');
    expect(calls, 2);
  });

  test(
    'película: sólo si hace falta, y el id de IMDb se pide una vez',
    () async {
      final portal = <String>[];
      final tmdb = <String>[];
      MovieSynopsisService make() => MovieSynopsisService(
        fetchImdbId: (id) async {
          portal.add(id);
          return 'tt9';
        },
        fetchJson: (path, query) async {
          tmdb.add(path);
          return found('Seis trabajadores quedan varados en Alaska.');
        },
      );
      final spanish = MovieItem(
        contentId: 'a',
        name: 'Arctic',
        description: 'Un hombre lucha por sobrevivir en el desierto helado.',
      );
      expect(await make().forMovie(spanish), isNull);
      expect(portal, isEmpty);
      expect(tmdb, isEmpty);

      final english = MovieItem(
        contentId: 'b',
        name: 'The Grey',
        description: 'After their plane crashes, the men fight to stay alive.',
      );
      expect(
        await make().forMovie(english),
        'Seis trabajadores quedan varados en Alaska.',
      );
      expect(portal, ['b']);
      expect(tmdb, ['/find/tt9']);
      // Otro arranque: ni el portal ni TMDb.
      expect(
        await make().forMovie(english),
        'Seis trabajadores quedan varados en Alaska.',
      );
      expect(portal, ['b']);
      expect(tmdb, ['/find/tt9']);
    },
  );

  test('película sin id de IMDb en el portal: no se busca', () async {
    final service = MovieSynopsisService(
      fetchImdbId: (_) async => null,
      fetchJson: (_, _) async => fail('no debía pedir'),
    );
    expect(
      await service.forMovie(MovieItem(contentId: 'c', name: 'Idilia')),
      isNull,
    );
  });
}
