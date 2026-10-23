import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/friends_roster.dart';

FriendInfo _friend(
  String id, {
  String? nick,
  bool online = false,
  String? channelId,
}) => FriendInfo(
  deviceId: id,
  userCode: 'MOAI-$id',
  nickname: nick,
  isOnline: online,
  currentChannelId: channelId,
);

void main() {
  group('FriendsRoster', () {
    test('ordena en línea primero y luego por nombre', () {
      final roster = FriendsRoster()
        ..replace([_friend('1', nick: 'zoe'), _friend('2', nick: 'Ana')])
        ..upsert(_friend('3', nick: 'Beto', online: true));
      expect(roster.friends.map((f) => f.nickname), ['Beto', 'Ana', 'zoe']);
    });

    test('applyPresences marca en línea, toma el canal y desconecta al resto', () {
      final roster = FriendsRoster()
        ..replace([_friend('1'), _friend('2', online: true, channelId: 'c9')]);

      final changed = roster.applyPresences([
        {'device_id': '1', 'channel_id': 'c1', 'nickname': 'Uno'},
      ]);

      expect(changed, isTrue);
      final byId = {for (final f in roster.friends) f.deviceId: f};
      expect(byId['1']!.isOnline, isTrue);
      expect(byId['1']!.currentChannelId, 'c1');
      expect(byId['1']!.nickname, 'Uno');
      expect(byId['2']!.isOnline, isFalse);
      // Sin cambios visibles la segunda vez.
      expect(
        roster.applyPresences([
          {'device_id': '1', 'channel_id': 'c1', 'nickname': 'Uno'},
        ]),
        isFalse,
      );
    });

    test('un canal null en la presencia borra el canal anterior', () {
      final roster = FriendsRoster()
        ..replace([_friend('1', online: true, channelId: 'c1')]);
      expect(roster.applyPresences([{'device_id': '1'}]), isTrue);
      expect(roster.friends.single.currentChannelId, isNull);
      expect(roster.watching('c1', null), isEmpty);
    });

    test('takeNewWatchers avisa una sola vez por canal', () {
      final roster = FriendsRoster()
        ..replace([_friend('1', nick: 'Uno', online: true, channelId: 'c1')]);
      expect(roster.takeNewWatchers('c1', null), ['Uno']);
      expect(roster.takeNewWatchers('c1', null), isEmpty);
      roster.resetNotified();
      expect(roster.takeNewWatchers('c1', null), ['Uno']);
    });

    test('applyDeviceRecord avisa al entrar al canal y no repite', () {
      final roster = FriendsRoster()
        ..replace([_friend('1', nick: 'Uno', online: true)]);
      final record = {
        'device_id': '1',
        'online': true,
        'current_channel_id': 'c1',
      };

      expect(roster.applyDeviceRecord(record, channelId: 'c1'), 'Uno');
      // Ya avisado: el sondeo siguiente no lo repite.
      expect(roster.takeNewWatchers('c1', null), isEmpty);
      // Cambio que no es de canal: solo actualiza la lista.
      expect(
        roster.applyDeviceRecord({...record, 'nickname': 'Uno2'}, channelId: 'c1'),
        '',
      );
      expect(roster.friends.single.nickname, 'Uno2');
    });

    test('applyDeviceRecord ignora dispositivos que no son amigos', () {
      final roster = FriendsRoster()..replace([_friend('1')]);
      expect(roster.applyDeviceRecord({'device_id': 'x'}), isNull);
    });
  });
}
