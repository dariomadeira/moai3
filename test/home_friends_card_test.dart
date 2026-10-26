import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_friends_card.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';

import 'helpers/spanish_translations.dart';

FriendInfo _friend(String name, {String? channelId, String? channelName}) =>
    FriendInfo(
      deviceId: 'dev-$name',
      userCode: 'MOAI-$name',
      nickname: name,
      isOnline: true,
      lastSeen: DateTime.now(),
      currentChannelId: channelId,
      currentChannelName: channelName,
    );

Channel _channel(String id, String name) =>
    Channel(id: id, name: name, logoUrl: '', fallbackUrls: const []);

void main() {
  /// La tarjeta como en el Chromecast: 960×540 a densidad 2, del ancho del
  /// panel y la altura de una de las 4 tarjetas del Inicio.
  Future<void> pumpCard(
    WidgetTester tester, {
    required List<FriendInfo> friends,
    String? myChannelId,
  }) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.reset());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 810,
              height: 99,
              child: HomeFriendsCard(
                friends: friends,
                selectedIndex: 0,
                isFocused: true,
                myChannelId: myChannelId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('sin amigos conectados lo avisa', (tester) async {
    await pumpCard(tester, friends: const []);
    expect(
      find.text('Ninguno de tus amigos está conectado ahora.'),
      findsOneWidget,
    );
  });

  testWidgets('muestra a cada amigo con su canal y marca "Con vos"', (
    tester,
  ) async {
    await pumpCard(
      tester,
      friends: [
        _friend('Ana', channelId: 'ar:tyc', channelName: 'TyC Sports'),
        _friend('Beto'),
      ],
      myChannelId: 'ar:tyc',
    );
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('TyC Sports'), findsOneWidget);
    expect(find.text('Con vos'), findsOneWidget);
    expect(find.text('Beto'), findsOneWidget);
    expect(find.text('No está mirando TV'), findsOneWidget);
    expect(find.text('OK: ir a su canal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('channelOf', () {
    final channels = [
      _channel('plugin:a:espn', 'ESPN HD'),
      _channel('plugin:b:tyc', 'TyC Sports'),
    ];

    test('por id', () {
      final f = _friend('Ana', channelId: 'plugin:b:tyc', channelName: 'TyC');
      expect(HomeFriendsItem.channelOf(f, channels)?.id, 'plugin:b:tyc');
    });

    test('por nombre si viene de otra extensión', () {
      final f = _friend('Ana', channelId: 'plugin:z:espn', channelName: 'ESPN');
      expect(HomeFriendsItem.channelOf(f, channels)?.id, 'plugin:a:espn');
    });

    test('sin canal o canal que no tengo', () {
      expect(HomeFriendsItem.channelOf(_friend('Ana'), channels), isNull);
      final f = _friend('Ana', channelId: 'x', channelName: 'Canal Raro');
      expect(HomeFriendsItem.channelOf(f, channels), isNull);
    });
  });
}
