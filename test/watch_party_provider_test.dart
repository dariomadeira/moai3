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

  List<FriendInfo> mockFriends = [];
  List<FriendInfo> mockRequests = [];

  /// Quiénes me agregaron; `null`: no se pudo saber (falla como sin red).
  Set<String>? mockIncoming;

  @override
  Future<Set<String>> getIncomingFriendIds(String deviceId) async {
    final incoming = mockIncoming;
    if (incoming == null) throw StateError('sin datos');
    return incoming;
  }

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

  @override
  Future<List<FriendInfo>> getFriends(String deviceId) async => mockFriends;

  @override
  Future<List<FriendInfo>> getFriendRequests(String deviceId) async =>
      mockRequests;

  @override
  Future<FriendInfo> addFriend({
    required String deviceId,
    required String myUserCode,
    required String friendUserCodeInput,
  }) async {
    final newFriend = FriendInfo(
      deviceId: 'dev-$friendUserCodeInput',
      userCode: friendUserCodeInput,
      nickname: 'Amigo $friendUserCodeInput',
      isOnline: true,
    );
    mockFriends.add(newFriend);
    mockRequests.removeWhere(
      (r) =>
          r.userCode == friendUserCodeInput ||
          r.deviceId == 'dev-$friendUserCodeInput',
    );
    return newFriend;
  }

  /// Usuarios que puede traer la búsqueda por apodo.
  List<FriendInfo> mockSearch = [];

  @override
  Future<List<FriendInfo>> searchByNickname({
    required String deviceId,
    required String query,
    int limit = 20,
  }) async => [
    for (final u in mockSearch)
      if ((u.nickname ?? '').toLowerCase().contains(query.toLowerCase())) u,
  ];

  /// Rechazadas (ids de quien la mandó).
  final List<String> rejected = [];

  @override
  Future<void> rejectFriendRequest({
    required String deviceId,
    required String requesterId,
  }) async {
    rejected.add(requesterId);
    mockRequests.removeWhere((r) => r.deviceId == requesterId);
    mockIncoming?.remove(requesterId);
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

    test(
      'reportCurrentChannel reporta y actualiza inmediatamente al cambiar de canal',
      () async {
        final provider = WatchPartyProvider(
          preferences: preferences,
          service: fakeService,
          identityService: identityService,
        );

        // Reporte de canal
        provider.reportCurrentChannel(
          channelId: 'ch-1',
          channelName: 'Canal 1',
        );

        // Se refleja inmediatamente en el provider y en el servicio
        expect(provider.currentChannelId, equals('ch-1'));
        expect(provider.currentChannelName, equals('Canal 1'));
        expect(fakeService.reportedChannelId, equals('ch-1'));
        expect(fakeService.reportedChannelName, equals('Canal 1'));

        // Cambio rápido a otro canal
        provider.reportCurrentChannel(
          channelId: 'ch-2',
          channelName: 'Canal 2',
        );
        expect(provider.currentChannelId, equals('ch-2'));
        expect(provider.currentChannelName, equals('Canal 2'));
        expect(fakeService.reportedChannelId, equals('ch-2'));

        // Misma llamada no duplica reporte
        final prevCount = fakeService.reportCount;
        provider.reportCurrentChannel(
          channelId: 'ch-2',
          channelName: 'Canal 2',
        );
        expect(fakeService.reportCount, equals(prevCount));

        provider.dispose();
      },
    );

    test('reportCurrentChannel con null limpia inmediatamente', () async {
      final provider = WatchPartyProvider(
        preferences: preferences,
        service: fakeService,
        identityService: identityService,
      );

      provider.reportCurrentChannel(channelId: 'ch-1', channelName: 'Canal 1');
      expect(provider.currentChannelId, equals('ch-1'));

      // Salida inmediata de canal o pausa
      provider.reportCurrentChannel();
      expect(provider.currentChannelId, isNull);
      expect(provider.currentChannelName, isNull);
      expect(fakeService.reportedChannelId, isNull);

      provider.dispose();
    });

    test(
      'friendsWatchingCurrentChannel filtra correctamente solo amigos en el mismo canal',
      () async {
        final provider = WatchPartyProvider(
          preferences: preferences,
          service: fakeService,
          identityService: identityService,
        );

        // Simular lista de amigos agregados
        provider.reportCurrentChannel(
          channelId: 'plugin:ar:tyc_sports',
          channelName: 'TyC Sports HD',
        );

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
        expect(
          friendInSameChannel.isWatchingSameChannel(
            provider.currentChannelId,
            provider.currentChannelName,
          ),
          isTrue,
        );
        expect(
          friendInOtherChannel.isWatchingSameChannel(
            provider.currentChannelId,
            provider.currentChannelName,
          ),
          isFalse,
        );
        expect(
          friendOffline.isWatchingSameChannel(
            provider.currentChannelId,
            provider.currentChannelName,
          ),
          isFalse,
        );

        provider.dispose();
      },
    );

    test(
      'loadFriends y acceptFriendRequest cargan solicitudes y mueven a amigos',
      () async {
        final requestFriend = FriendInfo(
          deviceId: 'dev-solicitante',
          userCode: 'MOAI-9999',
          nickname: 'Solicitante',
          isOnline: true,
        );
        fakeService.mockRequests = [requestFriend];
        fakeService.mockFriends = [];

        final provider = WatchPartyProvider(
          preferences: preferences,
          service: fakeService,
          identityService: identityService,
        );

        await provider.loadFriends();
        expect(provider.friendRequests.length, equals(1));
        expect(provider.friendRequests.first.userCode, equals('MOAI-9999'));
        expect(provider.friends.length, equals(0));

        // Aceptar la solicitud
        await provider.acceptFriendRequest(requestFriend);

        // Debe haberse agregado a amigos y quitado de solicitudes
        expect(provider.friends.length, equals(1));
        expect(provider.friends.first.userCode, equals('MOAI-9999'));
        expect(provider.friendRequests.length, equals(0));

        provider.dispose();
      },
    );

    test('una solicitud sin aceptar no cuenta como amigo conectado', () async {
      fakeService.mockFriends = [
        FriendInfo(
          deviceId: 'pendiente',
          userCode: 'MOAI-1111',
          isOnline: true,
        ),
      ];
      fakeService.mockIncoming = {};
      final provider = WatchPartyProvider(
        preferences: preferences,
        service: fakeService,
        identityService: identityService,
      );

      await provider.loadFriends();
      expect(provider.friends, hasLength(1));
      expect(provider.mutualFriends, isEmpty);
      expect(provider.hasOnlineFriends, isFalse);
      expect(provider.onlineFriendsCount, 0);

      // El otro aceptó.
      fakeService.mockIncoming = {'pendiente'};
      await provider.loadFriends();
      expect(provider.mutualFriends, hasLength(1));
      expect(provider.hasOnlineFriends, isTrue);
      expect(provider.onlineFriendsCount, 1);

      provider.dispose();
    });
  });
}
