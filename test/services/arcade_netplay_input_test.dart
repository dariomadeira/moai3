import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/games/services/arcade_emulator_service.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/features/games/services/arcade_webrtc_transport.dart';

ArcadeNetplayInputPacket _packet(int frame) =>
    ArcadeNetplayInputPacket(frame: frame, mask: 1, senderDeviceId: 'otro');

void main() {
  group('inputs del motor', () {
    test('separa pares frame y máscara', () {
      final inputs = ArcadeEmulatorService.decodeNetplayInputs(
        Int64List.fromList([3, 16, 4, 32]),
      );

      expect(inputs, [(frame: 3, mask: 16), (frame: 4, mask: 32)]);
    });

    test('sin datos o con un par incompleto no inventa inputs', () {
      expect(ArcadeEmulatorService.decodeNetplayInputs(null), isEmpty);
      expect(ArcadeEmulatorService.decodeNetplayInputs([7]), isEmpty);
    });
  });

  group('inputs del otro TV', () {
    final service = ArcadeNetplayService.instance;

    tearDown(service.detachRemoteInput);

    test('los que llegan antes del juego se entregan en orden', () {
      service.deliverRemoteInputForTest(_packet(3));
      service.deliverRemoteInputForTest(_packet(4));

      final frames = <int>[];
      service.attachRemoteInput((packet) => frames.add(packet.frame));
      service.deliverRemoteInputForTest(_packet(5));

      expect(frames, [3, 4, 5]);
    });

    test('los ya entregados no se repiten en otra partida', () {
      service.deliverRemoteInputForTest(_packet(3));
      service.attachRemoteInput((_) {});
      service.detachRemoteInput();

      final frames = <int>[];
      service.attachRemoteInput((packet) => frames.add(packet.frame));

      expect(frames, isEmpty);
    });
  });
}
