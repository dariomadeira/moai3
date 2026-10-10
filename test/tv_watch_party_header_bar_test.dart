import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/features/home/widgets/tv_watch_party_header_bar.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWatchPartyService extends WatchPartyService {
  @override
  Future<List<FriendInfo>> getFriends(String deviceId) async => [];
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
      expect(find.byType(AppIcon), findsNothing);
    });

    testWidgets('muestra las píldoras en modo de testeo / depuración', (tester) async {
      TvWatchPartyHeaderBar.setDebugMode(
        forceVisible: true,
        simulateIncomingAudio: true,
        simulateRecording: false,
        mockFriendsCount: 3,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvWatchPartyHeaderBar(),
          ),
        ),
      );

      expect(find.byType(AppIcon), findsWidgets);
      expect(find.text('watch_party_friend_speaking'), findsOneWidget);

      // Limpiar modo debug
      TvWatchPartyHeaderBar.debugForceVisible = false;
      TvWatchPartyHeaderBar.debugSimulateIncomingAudio = false;
    });
  });
}
