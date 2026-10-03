import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/models/voice_message_record.dart';
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
        'current_channel_id': 'plugin:ar:tyc_sports',
        'current_channel_name': 'TyC Sports HD',
      };

      final friend = FriendInfo.fromDeviceJson(json);

      expect(friend.deviceId, equals('dev-1234'));
      expect(friend.userCode, equals('MOAI-7421'));
      expect(friend.nickname, equals('Dario'));
      expect(friend.isOnline, isTrue);
      expect(friend.lastSeen, isNotNull);
      expect(friend.currentChannelId, equals('plugin:ar:tyc_sports'));
      expect(friend.currentChannelName, equals('TyC Sports HD'));
    });

    test('FriendInfo.isWatchingSameChannel evalúa coincidencia exacta y por nombre normalizado (SPEC-37)', () {
      final friendWatchingTyc = FriendInfo(
        deviceId: 'dev-2',
        userCode: 'MOAI-1111',
        isOnline: true,
        currentChannelId: 'plugin:ar:tyc_sports',
        currentChannelName: 'TyC Sports HD',
      );

      // 1. Mismo ID
      expect(friendWatchingTyc.isWatchingSameChannel('plugin:ar:tyc_sports'), isTrue);

      // 2. Distinto plugin pero mismo nombre normalizado ('TyC Sports')
      expect(
        friendWatchingTyc.isWatchingSameChannel(
          'plugin:daddylive:tyc',
          'TyC Sports (Argentina)',
        ),
        isTrue,
      );

      // 3. Canal completamente distinto
      expect(
        friendWatchingTyc.isWatchingSameChannel(
          'plugin:ar:telefe',
          'Telefe HD',
        ),
        isFalse,
      );

      // 4. Si el amigo está offline no coincide nunca
      final offlineFriend = friendWatchingTyc.copyWith(isOnline: false);
      expect(offlineFriend.isWatchingSameChannel('plugin:ar:tyc_sports'), isFalse);
    });

    test('FriendInfo evalúa isOnline como false si el latido (heartbeat) expiró por inactividad al cerrar la app', () {
      final now = DateTime.now();
      final staleLastSeen = now.subtract(const Duration(seconds: 90));

      final staleFriend = FriendInfo(
        deviceId: 'dev-stale',
        userCode: 'MOAI-9999',
        isOnline: true,
        lastSeen: staleLastSeen,
        currentChannelId: 'plugin:ar:espn',
        currentChannelName: 'ESPN',
      );

      expect(staleFriend.isOnline, isFalse);
      expect(staleFriend.isWatchingSameChannel('plugin:ar:espn', 'ESPN'), isFalse);
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

    test('VoiceMessageRecord serializa y deserializa en json correctamente (SPEC-37)', () {
      final now = DateTime.utc(2026, 10, 1, 12, 0, 0);
      final record = VoiceMessageRecord(
        id: 'msg-1234',
        senderDeviceId: 'dev-1',
        channelId: 'plugin:ar:tyc_sports',
        channelName: 'TyC Sports HD',
        audioUrl: 'https://supabase.co/storage/v1/object/public/voice_messages/audios/dev-1/audio.m4a',
        durationMs: 3500,
        createdAt: now,
      );

      final json = record.toJson();
      expect(json['id'], equals('msg-1234'));
      expect(json['sender_device_id'], equals('dev-1'));
      expect(json['channel_id'], equals('plugin:ar:tyc_sports'));
      expect(json['channel_name'], equals('TyC Sports HD'));
      expect(json['audio_url'], contains('audio.m4a'));
      expect(json['duration_ms'], equals(3500));

      final parsed = VoiceMessageRecord.fromJson(json);
      expect(parsed.id, equals('msg-1234'));
      expect(parsed.senderDeviceId, equals('dev-1'));
      expect(parsed.channelId, equals('plugin:ar:tyc_sports'));
      expect(parsed.channelName, equals('TyC Sports HD'));
      expect(parsed.audioUrl, equals(record.audioUrl));
      expect(parsed.durationMs, equals(3500));
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
