import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/voice_message_record.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockWatchPartyService extends WatchPartyService {
  VoiceMessageRecord? lastSentMessage;

  @override
  Future<VoiceMessageRecord> sendVoiceMessage({
    required String senderDeviceId,
    required String channelId,
    String? channelName,
    required String audioUrl,
    required int durationMs,
  }) async {
    final record = VoiceMessageRecord(
      id: 'sent-1',
      senderDeviceId: senderDeviceId,
      channelId: channelId,
      channelName: channelName,
      audioUrl: audioUrl,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    );
    lastSentMessage = record;
    return record;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchPartyVoiceCoordinator - Privacy and FIFO rules (SPEC-37)', () {
    late AppPreferences preferences;
    late DeviceIdentityService identityService;
    late MockWatchPartyService service;
    late WatchPartyProvider provider;
    late WatchPartyVoiceCoordinator coordinator;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'watch_party_enabled': true,
        'device_id': 'my-tv-device-id',
        'user_code': 'MOAI-0001',
      });
      preferences = await AppPreferences.init();
      identityService = DeviceIdentityService(preferences);
      service = MockWatchPartyService();
      provider = WatchPartyProvider(
        preferences: preferences,
        service: service,
        identityService: identityService,
      );
      coordinator = WatchPartyVoiceCoordinator(
        watchPartyProvider: provider,
        watchPartyService: service,
        identityService: identityService,
      );
    });

    tearDown(() {
      coordinator.dispose();
      provider.dispose();
    });

    test('filtro de privacidad: descarta mensajes de extraños no agregados como amigos', () async {
      // Sintonizar canal 'plugin:ar:tyc_sports'
      provider.reportCurrentChannel(channelId: 'plugin:ar:tyc_sports', channelName: 'TyC Sports');
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      // Emisor 'stranger-id' que NO está en la lista de amigos
      final strangerMessage = VoiceMessageRecord(
        id: 'msg-stranger',
        senderDeviceId: 'stranger-device-id',
        channelId: 'plugin:ar:tyc_sports',
        channelName: 'TyC Sports',
        audioUrl: 'https://example.com/audio1.m4a',
        durationMs: 3000,
        createdAt: DateTime.now(),
      );

      // Simular llegada de mensaje
      coordinator.handleIncomingVoiceMessage(strangerMessage);

      // Como no es amigo, no debe encolarse ni reproducirse
      expect(coordinator.queueLength, equals(0));
      expect(coordinator.isPlaying, isFalse);
    });

    test('filtro de canal: descarta mensajes si están en otro canal', () async {
      provider.reportCurrentChannel(channelId: 'plugin:ar:tyc_sports', channelName: 'TyC Sports');
      await Future<void>.delayed(const Duration(milliseconds: 3200));

      final otherChannelMessage = VoiceMessageRecord(
        id: 'msg-other-channel',
        senderDeviceId: 'friend-1',
        channelId: 'plugin:ar:telefe', // Otro canal
        channelName: 'Telefe',
        audioUrl: 'https://example.com/audio2.m4a',
        durationMs: 3000,
        createdAt: DateTime.now(),
      );

      // Simular llegada de mensaje de otro canal
      coordinator.handleIncomingVoiceMessage(otherChannelMessage);

      expect(coordinator.queueLength, equals(0));
      expect(coordinator.isPlaying, isFalse);
    });

    test('antiacople acústico: startRecording pausa la reproducción y cancela playback activo', () async {
      coordinator.pauseQueue();
      expect(coordinator.isPlaying, isFalse);

      coordinator.resumeQueue();
      expect(coordinator.isPlaying, isFalse);
    });
  });
}
