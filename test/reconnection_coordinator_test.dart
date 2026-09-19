import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/player/playback/reconnection_coordinator.dart';
import 'package:moai3/models/channel.dart';

void main() {
  group('ReconnectionCoordinator', () {
    final tvPublica = Channel(
      id: 'tv_publica',
      name: 'TV Pública',
      logoUrl: '',
      fallbackUrls: [
        'https://cdn03.gigared.com.ar/live/eds/TV_Publica/sa_live_dash/TV_Publica.mpd',
      ],
    );

    test('registra reintento con servidor activo', () {
      final coordinator = ReconnectionCoordinator(maxRetries: 2);
      final logs = <String>[];

      coordinator.scheduleReconnect(
        channel: tvPublica,
        isDisposed: false,
        onPlay: ({required bool isRetry}) {},
        onGiveUp: (_) => fail('no debería rendirse aún'),
        onRetrying: () {},
        onLog: (msg, {level = ReconnectLogLevel.info}) => logs.add(msg),
        reason: 'test error',
      );

      expect(logs.single, contains('Reintento 1/2'));
      expect(logs.single, contains('Moai Server'));
      coordinator.dispose();
    });

    test('se rinde e informa cuando se agotan los reintentos', () {
      final coordinator = ReconnectionCoordinator(maxRetries: 1);
      final logs = <String>[];
      String? giveUpMessage;

      coordinator.fallbackIndex = 0;
      coordinator.retryCount = 1;

      final scheduled = coordinator.scheduleReconnect(
        channel: tvPublica,
        isDisposed: false,
        onPlay: ({required bool isRetry}) {},
        onGiveUp: (m) => giveUpMessage = m,
        onRetrying: () {},
        onLog: (msg, {level = ReconnectLogLevel.info}) => logs.add(msg),
      );

      expect(scheduled, isFalse);
      expect(giveUpMessage, isNotNull);
      expect(logs.single, contains('Agotados 1 servidores'));
      coordinator.dispose();
    });

    test('handleServerSkip avanza fallback cuando hay más URLs', () {
      final multi = Channel(
        id: 'm',
        name: 'Multi',
        logoUrl: '',
        fallbackUrls: [
          'http://a.m3u8',
          'http://b.m3u8',
        ],
      );
      final coordinator = ReconnectionCoordinator();
      expect(coordinator.handleServerSkip(multi), isTrue);
      expect(coordinator.fallbackIndex, 1);
      expect(coordinator.handleServerSkip(multi), isFalse);
      coordinator.dispose();
    });
  });
}

