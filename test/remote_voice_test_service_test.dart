import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/remote_voice_test_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.infomak.moai.tv/remote_voice');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'checkHardware':
          return {
            'devices': [
              {
                'name': 'Remote Control Mic',
                'type': 15,
                'typeName': 'BLE_HEADSET',
              }
            ]
          };
        case 'hasPermission':
          return true;
        case 'requestPermission':
          return null;
        case 'startRecording':
          return {'success': true, 'path': '/tmp/test.m4a'};
        case 'stopRecording':
          return {'success': true, 'path': '/tmp/test.m4a', 'sizeBytes': 12345};
        case 'playRecording':
          return {'success': true};
        case 'stopPlayback':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('RemoteVoiceTestService queries hardware and methods correctly', () async {
    final hw = await RemoteVoiceTestService.checkHardware();
    expect(hw['devices'], isNotEmpty);

    final hasPerm = await RemoteVoiceTestService.hasPermission();
    expect(hasPerm, isTrue);

    final start = await RemoteVoiceTestService.startRecording();
    expect(start['success'], isTrue);

    final stop = await RemoteVoiceTestService.stopRecording();
    expect(stop['success'], isTrue);
    expect(stop['sizeBytes'], equals(12345));

    final play = await RemoteVoiceTestService.playRecording();
    expect(play['success'], isTrue);
  });
}
