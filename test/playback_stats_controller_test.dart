import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/playback_stats_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlaybackStatsController', () {
    test('setPlaying / setBuffering / setError actualizan status', () {
      final stats = PlaybackStatsController();
      expect(stats.status, PlaybackHealth.idle);

      stats.setBuffering();
      expect(stats.status, PlaybackHealth.buffering);
      expect(stats.showLoadingOverlay, isTrue);

      stats.setPlaying();
      expect(stats.status, PlaybackHealth.playing);
      expect(stats.showLoadingOverlay, isFalse);

      stats.setError();
      expect(stats.status, PlaybackHealth.error);
      // setIdle no limpia error (igual que Smart / diseño del controller).
      stats.setIdle();
      expect(stats.status, PlaybackHealth.error);
    });

    test('setFallbackIndex notifica cambio de servidor activo', () {
      final stats = PlaybackStatsController();
      expect(stats.fallbackIndex, 0);
      stats.setFallbackIndex(2);
      expect(stats.fallbackIndex, 2);
    });

    test('setBackend legacy actualiza backend', () {
      final stats = PlaybackStatsController();
      stats.setBackend(PlayerBackend.legacyVideoPlayer);
      expect(stats.backend, PlayerBackend.legacyVideoPlayer);
      expect(stats.showsMediaKitStats, isFalse);
    });
  });
}


