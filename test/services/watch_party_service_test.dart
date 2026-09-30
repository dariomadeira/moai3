import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/watch_party_service.dart';

void main() {
  group('FriendInfo & Friendship Models (SPEC-36)', () {
    test('FriendInfo.fromDeviceJson parsea correctamente los campos y la presencia', () {
      final json = {
        'device_id': 'dev-1234',
        'user_code': 'MOAI-7421',
        'nickname': 'Dario',
        'online': true,
        'last_seen': '2026-09-29T20:00:00.000Z',
      };

      final friend = FriendInfo.fromDeviceJson(json);

      expect(friend.deviceId, equals('dev-1234'));
      expect(friend.userCode, equals('MOAI-7421'));
      expect(friend.nickname, equals('Dario'));
      expect(friend.isOnline, isTrue);
      expect(friend.lastSeen, isNotNull);
    });

    test('Friendship serializa y deserializa en json', () {
      final now = DateTime.now();
      final friendship = Friendship(
        deviceId: 'my-device',
        friendDeviceId: 'friend-device',
        createdAt: now,
      );

      final json = friendship.toJson();
      expect(json['device_id'], equals('my-device'));
      expect(json['friend_device_id'], equals('friend-device'));

      final parsed = Friendship.fromJson(json);
      expect(parsed.deviceId, equals('my-device'));
      expect(parsed.friendDeviceId, equals('friend-device'));
    });
  });

  group('WatchPartyService Business Rules', () {
    test('addFriend rechaza cuando el usuario intenta agregarse a sí mismo (RB-05)', () async {
      final service = WatchPartyService();

      expect(
        () => service.addFriend(
          deviceId: 'dev-1',
          myUserCode: 'MOAI-7421',
          friendUserCodeInput: '7421',
        ),
        throwsA(
          isA<WatchPartyException>().having(
            (e) => e.message,
            'message',
            contains('friend_add_error_self'),
          ),
        ),
      );

      expect(
        () => service.addFriend(
          deviceId: 'dev-1',
          myUserCode: 'MOAI-7421',
          friendUserCodeInput: 'MOAI-7421',
        ),
        throwsA(
          isA<WatchPartyException>().having(
            (e) => e.message,
            'message',
            contains('friend_add_error_self'),
          ),
        ),
      );
    });
  });
}
