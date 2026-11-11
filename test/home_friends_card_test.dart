import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_friends_card.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/widgets/tv_common/friend_avatar.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';

import 'helpers/spanish_translations.dart';
import 'watch_party_provider_test.dart' show FakeWatchPartyService;

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
    // Abajo, el botón que abre Gestionar amigos (entra en la tarjeta).
    final button = tester.widget<HomeGlassButton>(
      find.widgetWithText(HomeGlassButton, 'Gestionar amigos'),
    );
    // Del tamaño estándar de los botones de las tarjetas, no el grande.
    expect(button.large, isFalse);
    expect(tester.takeException(), isNull);
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
    // La línea del resumen no cambia con el foco.
    expect(find.text('OK: ir a su canal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('avatares', () {
    test('el mismo usuario recibe siempre el mismo moai', () {
      expect(
        FriendAvatars.assetFor('MOAI-AB12'),
        FriendAvatars.assetFor(' moai-ab12 '),
      );
      // Valor fijo: si cambia el cálculo, a todos les cambia el avatar.
      expect(
        FriendAvatars.assetFor('MOAI-AB12'),
        'assets/images/avatars/moai_8.webp',
      );
    });

    test('usa los 9 moais', () {
      final used = {
        for (var i = 0; i < 500; i++) FriendAvatars.assetFor('MOAI-$i'),
      };
      expect(used, {
        for (var n = 1; n <= FriendAvatars.count; n++)
          'assets/images/avatars/moai_$n.webp',
      });
      for (final asset in used) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    });
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

  testWidgets('sin amigos conectados, OK sobre la tarjeta abre el modal', (
    tester,
  ) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.reset());
    SharedPreferences.setMockInitialValues({
      'device_user_code': 'MOAI-1234',
      'device_id': 'tv-1',
    });
    final prefs = await AppPreferences.init();
    final watchParty = WatchPartyProvider(
      preferences: prefs,
      service: FakeWatchPartyService()..mockIncoming = {},
      identityService: DeviceIdentityService(prefs),
    );
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: watchParty,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 810,
                height: 99,
                child: HomeFriendsItem(
                  focusNode: focus,
                  onKeyLeft: () {},
                  onKeyUp: () {},
                  onKeyDown: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(TvFriendsDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
