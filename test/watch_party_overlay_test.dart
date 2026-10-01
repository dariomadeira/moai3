import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/player/watch_party_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeService extends WatchPartyService {
  final List<FriendInfo> fakeFriends;
  FakeService({this.fakeFriends = const []});

  @override
  Future<List<FriendInfo>> getFriends(String deviceId) async => fakeFriends;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchPartyOverlay Widget Tests (SPEC-37)', () {
    late AppPreferences prefs;
    late DeviceIdentityService identityService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'watch_party_enabled': true,
        'device_id': 'my-device-id',
        'user_code': 'MOAI-1000',
      });
      prefs = await AppPreferences.init();
      identityService = DeviceIdentityService(prefs);
    });

    testWidgets('permanece oculto si Watch Party está desactivado', (tester) async {
      final service = FakeService();
      final provider = WatchPartyProvider(
        preferences: prefs,
        service: service,
        identityService: identityService,
      );
      await provider.setEnabled(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ChangeNotifierProvider<WatchPartyProvider>.value(
                  value: provider,
                  child: const WatchPartyOverlay(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Symbols.mic), findsNothing);
      provider.dispose();
    });

    testWidgets('permanece oculto si no hay amigos en el mismo canal', (tester) async {
      final service = FakeService(fakeFriends: [
        FriendInfo(
          deviceId: 'friend-1',
          userCode: 'MOAI-2000',
          nickname: 'Carlos',
          isOnline: true,
          currentChannelId: 'plugin:ar:telefe', // Otro canal
        ),
      ]);
      final provider = WatchPartyProvider(
        preferences: prefs,
        service: service,
        identityService: identityService,
      );
      await provider.loadFriends();

      // Sintonizo TyC Sports
      provider.reportCurrentChannel(channelId: 'plugin:ar:tyc_sports', channelName: 'TyC Sports');
      await tester.pump(const Duration(seconds: 4));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                ChangeNotifierProvider<WatchPartyProvider>.value(
                  value: provider,
                  child: const WatchPartyOverlay(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Symbols.mic), findsNothing);
      provider.dispose();
    });

    testWidgets('se muestra con chip de amigo y botón de mic si un amigo está en el mismo canal', (tester) async {
      final friendJuan = FriendInfo(
        deviceId: 'friend-juan',
        userCode: 'MOAI-3000',
        nickname: 'Juan',
        isOnline: true,
        currentChannelId: 'plugin:ar:tyc_sports',
        currentChannelName: 'TyC Sports',
      );
      final service = FakeService(fakeFriends: [friendJuan]);
      final provider = WatchPartyProvider(
        preferences: prefs,
        service: service,
        identityService: identityService,
      );
      await provider.loadFriends();

      // Sintonizo TyC Sports
      provider.reportCurrentChannel(channelId: 'plugin:ar:tyc_sports', channelName: 'TyC Sports');
      await tester.pump(const Duration(seconds: 4));

      final coordinator = WatchPartyVoiceCoordinator(
        watchPartyProvider: provider,
        watchPartyService: service,
        identityService: identityService,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider<WatchPartyProvider>.value(value: provider),
                    ChangeNotifierProvider<WatchPartyVoiceCoordinator>.value(value: coordinator),
                  ],
                  child: const WatchPartyOverlay(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Verifica el chip izquierdo
      expect(find.text('Juan está viendo'), findsOneWidget);

      // Verifica el botón central de micrófono
      expect(find.byIcon(Symbols.mic), findsOneWidget);

      coordinator.dispose();
      provider.dispose();
    });
  });
}
