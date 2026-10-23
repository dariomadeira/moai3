import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/coordinators/presence_coordinator.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'watch_party_provider_test.dart' show FakeWatchPartyService;

class _FakePresence extends SupabasePresenceService {
  // ignore: close_sinks (se cierra en tearDown)
  final device = StreamController<DeviceRecord>();
  final online = <bool>[];

  @override
  Future<void> updateOnlineStatus({
    required String deviceId,
    required bool online,
  }) async =>
      this.online.add(online);

  @override
  Future<void> sendHeartbeat({required String deviceId}) async {}

  @override
  Stream<DeviceRecord> watchDevice(String deviceId) => device.stream;
}

DeviceRecord _record({required bool active, String? reason}) {
  final now = DateTime.now();
  return DeviceRecord(
    deviceId: 'tv-1',
    appVersion: '3.1.0',
    isActive: active,
    blockReason: reason,
    online: true,
    firstSeen: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePresence presence;
  late ChannelProvider channels;
  late WatchPartyProvider watchParty;
  late PresenceCoordinator coordinator;
  final blocks = <String?>[];

  final channel = Channel(
    id: 'plugin:ar:tyc',
    name: 'TyC Sports',
    logoUrl: '',
    fallbackUrls: const ['https://example.com/tyc.m3u8'],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'watch_party_enabled': true,
      'device_id': 'tv-1',
      'user_code': 'MOAI-0001',
    });
    final prefs = await AppPreferences.init();
    presence = _FakePresence();
    channels = ChannelProvider(prefs);
    watchParty = WatchPartyProvider(
      preferences: prefs,
      service: FakeWatchPartyService(),
      identityService: DeviceIdentityService(prefs),
    );
    blocks.clear();
    coordinator = PresenceCoordinator(
      deviceId: 'tv-1',
      presence: presence,
      channels: channels,
      watchParty: watchParty,
      onBlocked: blocks.add,
    );
  });

  tearDown(() {
    unawaited(presence.device.close());
    coordinator.dispose();
    watchParty.dispose();
  });

  test('fuera de TV no se reporta el canal aunque cambie', () {
    coordinator.setMode(PresenceMode.offline);
    channels.selectChannel(channel);

    expect(watchParty.currentChannelId, isNull);
    expect(presence.online.last, isFalse);
  });

  test('en TV se reporta el canal que se mira', () {
    coordinator.setMode(PresenceMode.watching);
    channels.selectChannel(channel);

    expect(watchParty.currentChannelId, channel.id);
    expect(presence.online.last, isTrue);
  });

  test('el bloqueo en vivo avisa una sola vez', () async {
    presence.device
      ..add(_record(active: true))
      ..add(_record(active: false, reason: 'Pago vencido'))
      ..add(_record(active: false, reason: 'Pago vencido'));
    await Future<void>.delayed(Duration.zero);

    expect(blocks, ['Pago vencido']);
  });
}
