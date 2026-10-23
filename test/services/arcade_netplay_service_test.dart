import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/games/models/arcade_netplay_state.dart';

void main() {
  group('ArcadeNetplay Models & Flow', () {
    test('ArcadeNetplayInvite serialization and deserialization works correctly', () {
      const invite = ArcadeNetplayInvite(
        sessionId: 'test-session-123',
        hostDeviceId: 'host-dev-1',
        hostNickname: 'Player One',
        guestDeviceId: 'target-dev-2',
        romName: 'Street Fighter II',
        romFilename: 'sf2.zip',
        romUrl: 'https://example.com/roms/sf2.zip',
      );

      final map = invite.toMap();
      final fromMap = ArcadeNetplayInvite.fromMap(map);

      expect(fromMap.sessionId, equals('test-session-123'));
      expect(fromMap.hostDeviceId, equals('host-dev-1'));
      expect(fromMap.hostNickname, equals('Player One'));
      expect(fromMap.guestDeviceId, equals('target-dev-2'));
      expect(fromMap.romName, equals('Street Fighter II'));
      expect(fromMap.romFilename, equals('sf2.zip'));
      expect(fromMap.romUrl, equals('https://example.com/roms/sf2.zip'));
    });

    test('ArcadeNetplaySession state progression and peer tracking', () {
      final session = ArcadeNetplaySession(
        sessionId: 'session-abc',
        isHost: true,
        myDeviceId: 'dev-1',
        myNickname: 'Player 1',
        peerDeviceId: 'dev-2',
        peerNickname: 'Amigo Pro',
        romFilename: 'kof98.zip',
        romName: 'The King of Fighters 98',
        romUrl: 'https://example.com/kof98.zip',
      );

      expect(session.isHost, isTrue);
      expect(session.status, equals(ArcadeNetplayStatus.preparingRoms));

      session.myProgress = 1.0;
      session.peerProgress = 1.0;
      session.status = ArcadeNetplayStatus.ready;

      session.status = ArcadeNetplayStatus.inGame;
      expect(session.status, equals(ArcadeNetplayStatus.inGame));
    });
  });
}
