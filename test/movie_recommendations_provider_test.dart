import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends MovieRecommendationsApi {
  List<Map<String, dynamic>> rows = [];
  bool offline = false;
  int fetches = 0;
  final sent = <String>[];
  final removed = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async {
    fetches++;
    return rows;
  }

  @override
  Future<void> recommend(String deviceId, MovieItem movie) async {
    if (offline) throw Exception('sin red');
    sent.add(movie.contentId);
  }

  @override
  Future<void> remove(String deviceId, String contentId) async {
    if (offline) throw Exception('sin red');
    removed.add(contentId);
  }
}

Map<String, dynamic> _row(String friend, String id) => {
  'recommender_device_id': friend,
  'content_id': id,
  'movie': MovieItem(contentId: id, name: 'Película $id').toJson(),
};

MovieItem _movie(String id) => MovieItem(contentId: id, name: id);

void main() {
  late _FakeApi api;
  late MovieRecommendationsProvider provider;
  late Set<String> watched;
  const friends = {'ana': 'Ana', 'beto': 'Beto'};

  MovieRecommendationsProvider build() => MovieRecommendationsProvider(
    api: api,
    isWatched: (id) async => watched.contains(id),
  );

  Future<void> connect(
    MovieRecommendationsProvider target, [
    Map<String, String> who = friends,
  ]) async {
    target.setFriends(deviceId: 'yo', friends: who);
    await target.refresh();
    await pumpEventQueue();
  }

  List<String> ids() => [for (final i in provider.items) i.movie.contentId];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _FakeApi();
    watched = {};
    provider = build();
  });

  test('agrupa por película y conserva quiénes la recomendaron', () async {
    api.rows = [_row('ana', 'm1'), _row('beto', 'm2'), _row('beto', 'm1')];
    await connect(provider);

    expect(ids(), ['m1', 'm2']);
    expect(provider.items.first.names, ['Ana', 'Beto']);
  });

  test('ignora filas de quien ya no es amigo', () async {
    api.rows = [_row('otro', 'm1')];
    await connect(provider);

    expect(provider.items, isEmpty);
  });

  test(
    'no vuelve a consultar antes de tiempo, salvo si cambian los amigos',
    () async {
      await connect(provider);
      final before = api.fetches;
      await provider.refresh();
      expect(api.fetches, before);

      await connect(provider, {'ana': 'Ana'});
      expect(api.fetches, greaterThan(before));
    },
  );

  test('sin amigos no consulta y no se puede recomendar', () async {
    await connect(provider, const {});

    expect(api.fetches, 0);
    expect(provider.canRecommend, isFalse);
  });

  group('votos', () {
    setUp(() => connect(provider));

    test('👍 publica', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.up);

      expect(api.sent, ['m1']);
      expect(provider.voteOf('m1'), MovieVote.up);
      expect(provider.shouldAsk('m1'), isFalse);
    });

    test('👎 no sale del TV pero no se vuelve a preguntar', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.down);

      expect(api.sent, isEmpty);
      expect(api.removed, isEmpty);
      expect(provider.shouldAsk('m1'), isFalse);
    });

    test('pasar de 👍 a 👎 borra la publicación', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.up);
      await provider.toggleVote(_movie('m1'), MovieVote.down);

      expect(api.removed, ['m1']);
      expect(provider.voteOf('m1'), MovieVote.down);
    });

    test('pasar de 👎 a 👍 publica', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.down);
      await provider.toggleVote(_movie('m1'), MovieVote.up);

      expect(api.sent, ['m1']);
      expect(provider.voteOf('m1'), MovieVote.up);
    });

    test('repetir 👍 lo quita y borra la publicación', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.up);
      await provider.toggleVote(_movie('m1'), MovieVote.up);

      expect(api.removed, ['m1']);
      expect(provider.voteOf('m1'), isNull);
      expect(provider.shouldAsk('m1'), isTrue);
    });

    test('repetir 👎 lo quita sin tocar el servidor', () async {
      await provider.toggleVote(_movie('m1'), MovieVote.down);
      await provider.toggleVote(_movie('m1'), MovieVote.down);

      expect(api.removed, isEmpty);
      expect(provider.voteOf('m1'), isNull);
    });
  });

  group('sin conexión', () {
    setUp(() => connect(provider));

    Future<void> reconnect() async {
      api.offline = false;
      await connect(provider, {'ana': 'Ana'});
    }

    test('un 👍 queda pendiente y se manda después', () async {
      api.offline = true;
      await provider.setVote(_movie('m1'), MovieVote.up);
      expect(api.sent, isEmpty);

      await reconnect();

      expect(api.sent, ['m1']);
    });

    test('un 👍 que nunca salió y se quita no llega al servidor', () async {
      api.offline = true;
      await provider.setVote(_movie('m1'), MovieVote.up);
      await provider.setVote(_movie('m1'), null);

      await reconnect();

      expect(api.sent, isEmpty);
      expect(api.removed, isEmpty);
    });

    test('quitar un 👍 publicado se reintenta', () async {
      await provider.setVote(_movie('m1'), MovieVote.up);
      api.offline = true;
      await provider.setVote(_movie('m1'), null);
      expect(api.removed, isEmpty);

      await reconnect();

      expect(api.removed, ['m1']);
    });
  });

  group('tarjeta', () {
    test('borrar saca solo de este TV y persiste', () async {
      api.rows = [_row('ana', 'm1'), _row('ana', 'm2')];
      await connect(provider);

      await provider.dismiss('m1');
      expect(ids(), ['m2']);
      expect(api.removed, isEmpty);

      final again = build();
      await connect(again);
      expect(again.items.map((i) => i.movie.contentId), ['m2']);
    });

    test('borrar todas vacía la tarjeta', () async {
      api.rows = [_row('ana', 'm1'), _row('beto', 'm2')];
      await connect(provider);

      await provider.dismissAll();

      expect(provider.items, isEmpty);
    });

    test('lo ya votado no aparece', () async {
      api.rows = [_row('ana', 'm1')];
      await connect(provider);
      expect(provider.items, hasLength(1));

      await provider.setVote(_movie('m1'), MovieVote.down);

      expect(provider.items, isEmpty);
    });

    test('lo ya visto no aparece, sin salir a la red', () async {
      api.rows = [_row('ana', 'm1'), _row('ana', 'm2')];
      await connect(provider);
      final before = api.fetches;

      watched.add('m1');
      await provider.refresh();

      expect(ids(), ['m2']);
      expect(api.fetches, before);
    });
  });
}
