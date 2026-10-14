import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/games/services/arcade_webrtc_transport.dart';

void main() {
  group('ArcadeNetplayInputPacket', () {
    test('serializa y parsea frame/mask/sender', () {
      const packet = ArcadeNetplayInputPacket(
        frame: 42,
        mask: 0x0F,
        senderDeviceId: 'dev-a',
      );
      final json = packet.toJson();
      final parsed = ArcadeNetplayInputPacket.tryParse(json);
      expect(parsed, isNotNull);
      expect(parsed!.frame, 42);
      expect(parsed.mask, 0x0F);
      expect(parsed.senderDeviceId, 'dev-a');
    });

    test('ignora mensajes que no son input', () {
      expect(
        ArcadeNetplayInputPacket.tryParse({'t': 'netplay_start'}),
        isNull,
      );
    });
  });
}
