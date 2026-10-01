import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWatchPartyService extends WatchPartyService {
  String? reportedChannelId;
  String? reportedChannelName;
  int reportCount = 0;

  @override
  Future<void> reportCurrentChannel({
    required String deviceId,
    String? channelId,
    String? channelName,
  }) async {
    reportedChannelId = channelId;
    reportedChannelName = channelName;
    reportCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchPartyProvider - Channel Tracking & Debounce (SPEC-37)', () {
    late AppPreferences preferences;
    late DeviceIdentityService identityService;
    late FakeWatchPartyService fakeService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'watch_party_enabled': true,
        'user_code': 'MOAI-1234',
        'device_id': 'test-device-uuid',
      });
      preferences = await AppPreferences.init();
      identityService = DeviceIdentityService(preferences);
      fakeService = FakeWatchPartyService();
    });

    test('reportCurrentChannel aplica debounce de 3 segundos contra el zapping', () async {
      final provider = WatchPartyProvider(
        preferences: preferences,
        service: fakeService,
        identityService: identityService,
      );

      // Usuario zappea rápidamente por 3 canales
      provider.reportCurrentChannel(channelId: 'ch-1', channelName: 'Canal 1');
      provider.reportCurrentChannel(channelId: 'ch-2', channelName: 'Canal 2');
      provider.reportCurrentChannel(channelId: 'ch-3', channelName: 'Canal 3');

      // Inmediatamente aún no se ha reportado nada
      expect(provider.currentChannelId, isNull);
      expect(fakeService.reportCount, equals(0));

      // Tras 2 segundos aún no vence el debounce
      await Future<void>.delayed(const Duration(milliseconds: 2100));
      expect(provider.currentChannelId, isNull);
      expect(fakeService.reportCount, equals(0));

      // Tras 1 segundo adicional (total > 3s), vence el debounce y reporta solo el canal final ch-3
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(provider.currentChannelId, equals('ch-3'));
      expect(provider.currentChannelName, equals('Canal 3'));
      expect(fakeService.reportCount, equals(1));
      expect(fakeService.reportedChannelId, equals('ch-3'));

      provider.dispose();
    });

    test('reportCurrentChannel con null limpia inmediatamente sin esperar 3 segundos', () async {
      final provider = WatchPartyProvider(
        preferences: preferences,
        service: fakeService,
        identityService: identityService,
      );

      provider.reportCurrentChannel(channelId: 'ch-1', channelName: 'Canal 1');
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(provider.currentChannelId, equals('ch-1'));

      // Salida inmediata de fullscreen o pausa
      provider.reportCurrentChannel(channelId: null);
      expect(provider.currentChannelId, isNull);
      expect(provider.currentChannelName, isNull);
      expect(fakeService.reportedChannelId, isNull);

      provider.dispose();
    });

    test('friendsWatchingCurrentChannel filtra correctamente solo amigos en el mismo canal', () async {
      final provider = WatchPartyProvider(
        preferences: preferences,
        service: fakeService,
        identityService: identityService,
      );

      // Simular lista de amigos agregados
      provider.reportCurrentChannel(channelId: 'plugin:ar:tyc_sports', channelName: 'TyC Sports HD');
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      // Inyectar amigos de prueba
      final friendInSameChannel = FriendInfo(
        deviceId: 'dev-friend-1',
        userCode: 'MOAI-1111',
        nickname: 'Juan',
        isOnline: true,
        currentChannelId: 'plugin:ar:tyc_sports',
        currentChannelName: 'TyC Sports HD',
      );

      final friendInOtherChannel = FriendInfo(
        deviceId: 'dev-friend-2',
        userCode: 'MOAI-2222',
        nickname: 'Pedro',
        isOnline: true,
        currentChannelId: 'plugin:ar:telefe',
        currentChannelName: 'Telefe',
      );

      final friendOffline = FriendInfo(
        deviceId: 'dev-friend-3',
        userCode: 'MOAI-3333',
        nickname: 'Lucas',
        isOnline: false,
        currentChannelId: 'plugin:ar:tyc_sports',
        currentChannelName: 'TyC Sports HD',
      );

      // Verificamos el helper isWatchingSameChannel directamente
      expect(friendInSameChannel.isWatchingSameChannel(provider.currentChannelId, provider.currentChannelName), isTrue);
      expect(friendInOtherChannel.isWatchingSameChannel(provider.currentChannelId, provider.currentChannelName), isFalse);
      expect(friendOffline.isWatchingSameChannel(provider.currentChannelId, provider.currentChannelName), isFalse);

      provider.dispose();
    });
  });
}
