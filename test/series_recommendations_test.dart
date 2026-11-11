import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_recommendations_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/services/series_recommendations_api.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/state/series_recommendations_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// Como la tabla de series: lo publicado (con la temporada) y lo leído.
class _FakeSeriesApi extends MovieRecommendationsApi {
  List<Map<String, dynamic>> rows = [];
  final sent = <Map<String, dynamic>>[];
  final removed = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async =>
      rows;

  @override
  Future<void> recommendJson(
    String deviceId,
    Map<String, dynamic> json,
  ) async => sent.add(json);

  @override
  Future<void> remove(String deviceId, String contentId) async =>
      removed.add(contentId);
}

MovieItem _series(String id) =>
    MovieItem(contentId: id, name: 'Serie $id', programType: 'teleplay');

void main() {
  late _FakeSeriesApi api;
  late SeriesRecommendationsProvider provider;

  setUp(() async {
    useSpanishTranslations();
    SharedPreferences.setMockInitialValues({});
    api = _FakeSeriesApi();
    provider = SeriesRecommendationsProvider(
      api: api,
      isWatched: (_) async => false,
    );
    provider.setFriends(deviceId: 'yo', friends: const {'ana': 'Ana'});
    await provider.refresh();
    await pumpEventQueue();
  });

  test('la serie es la misma en todos los TV: la T1 de contentId menor', () {
    const all = [
      SeriesSeason(contentId: 's2', number: 2),
      SeriesSeason(contentId: 'zz-oficial', number: 1),
      SeriesSeason(contentId: 'aa-paralela', number: 1),
    ];
    expect(SeriesSeasonDetail.recommendationKey(all, 'x'), 'aa-paralela');
    expect(
      SeriesSeasonDetail.recommendationKey(all.reversed.toList(), 'x'),
      'aa-paralela',
    );
    expect(SeriesSeasonDetail.recommendationKey(const [], 'x'), 'x');
  });

  test('👍 publica la serie con la temporada; otro 👍 la actualiza', () async {
    await provider.setVote(
      _series('s1'),
      MovieVote.up,
      extra: {SeriesRecommendationsApi.seasonKey: 1},
    );
    expect(api.sent.single['contentId'], 's1');
    expect(api.sent.single[SeriesRecommendationsApi.seasonKey], 1);

    await provider.setVote(
      _series('s1'),
      MovieVote.up,
      extra: {SeriesRecommendationsApi.seasonKey: 3},
    );
    expect(api.sent.last[SeriesRecommendationsApi.seasonKey], 3);

    // 👎 en otra temporada: se borra (no se comparte).
    await provider.setVote(_series('s1'), MovieVote.down);
    expect(api.removed, ['s1']);
  });

  test('pregunta una vez por temporada', () async {
    expect(provider.shouldAskSeason('s1', 1), isTrue);
    await provider.markAskedSeason('s1', 1);
    expect(provider.shouldAskSeason('s1', 1), isFalse);
    expect(provider.shouldAskSeason('s1', 2), isTrue);
  });

  test('sin amigos no pregunta', () async {
    provider.setFriends(deviceId: 'yo', friends: const {});
    expect(provider.shouldAskSeason('s1', 1), isFalse);
  });

  test('lo de los amigos trae hasta qué temporada llegaron', () {
    final items = groupRecommendations(
      [
        {
          'recommender_device_id': 'ana',
          'content_id': 's1',
          'movie': {
            ..._series('s1').toJson(),
            SeriesRecommendationsApi.seasonKey: 3,
          },
        },
      ],
      friendNames: const {'ana': 'Ana'},
      hidden: const {},
    );
    expect(items.single.seasonReached, 3);
    expect(items.single.names, ['Ana']);
  });

  testWidgets('la tarjeta de series: "Hasta T3" sobre la serie', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 280,
            child: HomeRecommendationsCard(
              items: [
                FriendRecommendation(
                  movie: _series('s1'),
                  names: ['Ana'],
                  seasonReached: 3,
                ),
              ],
              selectedIndex: 0,
              series: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Hasta T3'), findsOneWidget);
    expect(find.text('Series'), findsOneWidget);
  });
}
