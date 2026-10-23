import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/features/home/widgets/tv_watch_party_header_bar.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWatchPartyService extends WatchPartyService {
  final List<FriendInfo> friends;
  _FakeWatchPartyService({this.friends = const []});

  @override
  Future<List<FriendInfo>> getFriends(String deviceId) async => friends;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvWatchPartyHeaderBar Widget Tests', () {
    late AppPreferences prefs;
    late DeviceIdentityService identityService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'watch_party_enabled': true,
        'device_id': 'test-device-id',
        'user_code': 'MOAI-9999',
      });
      prefs = await AppPreferences.init();
      identityService = DeviceIdentityService(prefs);
    });

    testWidgets('permanece oculto si Watch Party está desactivado', (tester) async {
      final service = _FakeWatchPartyService();
      final provider = WatchPartyProvider(
        preferences: prefs,
        service: service,
        identityService: identityService,
      );
      await provider.setEnabled(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WatchPartyProvider>.value(
              value: provider,
              child: const TvWatchPartyHeaderBar(),
            ),
          ),
        ),
      );

      expect(find.byType(TvWatchPartyHeaderBar), findsOneWidget);
      expect(find.byIcon(MoaiIcons.mic), findsNothing);
      expect(find.byIcon(MoaiIcons.voiceSelection), findsNothing);
    });

    testWidgets('muestra el micrófono si un amigo mira el mismo canal', (tester) async {
      final service = _FakeWatchPartyService(friends: [
        FriendInfo(
          deviceId: 'friend-ana',
          userCode: 'MOAI-3001',
          nickname: 'Ana',
          isOnline: true,
          currentChannelId: 'plugin:ar:tyc_sports',
          currentChannelName: 'TyC Sports',
        ),
      ]);
      final provider = WatchPartyProvider(
        preferences: prefs,
        service: service,
        identityService: identityService,
      );
      await provider.loadFriends();
      provider.reportCurrentChannel(
        channelId: 'plugin:ar:tyc_sports',
        channelName: 'TyC Sports',
      );
      await tester.pump(const Duration(seconds: 4));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<WatchPartyProvider>.value(
              value: provider,
              child: const TvWatchPartyHeaderBar(),
            ),
          ),
        ),
      );

      expect(find.byIcon(MoaiIcons.mic), findsOneWidget);
      provider.dispose();
    });
  });
}
