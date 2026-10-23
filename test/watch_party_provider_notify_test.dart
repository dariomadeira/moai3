import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_party_provider_test.dart' show FakeWatchPartyService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el sondeo de amigos solo notifica si cambió algo visible', () async {
    SharedPreferences.setMockInitialValues({
      'watch_party_enabled': true,
      'device_id': 'tv-1',
      'user_code': 'MOAI-0001',
    });
    final prefs = await AppPreferences.init();
    final service = FakeWatchPartyService()
      ..mockFriends = [
        FriendInfo(deviceId: 'ana', userCode: 'MOAI-2', isOnline: true),
      ];
    final provider = WatchPartyProvider(
      preferences: prefs,
      service: service,
      identityService: DeviceIdentityService(prefs),
    );
    await provider.loadFriends();

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.loadFriends();
    expect(notifications, 0, reason: 'mismos datos');

    service.mockFriends = [
      FriendInfo(
        deviceId: 'ana',
        userCode: 'MOAI-2',
        isOnline: true,
        currentChannelId: 'plugin:ar:tyc',
      ),
    ];
    await provider.loadFriends();
    expect(notifications, 1, reason: 'cambió el canal del amigo');

    provider.dispose();
  });
}
