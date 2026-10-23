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

      stats.setPlaying();
      expect(stats.status, PlaybackHealth.playing);

      stats.setError();
      expect(stats.status, PlaybackHealth.error);
      // Un error no se pisa con playing/buffering hasta reconectar.
      stats.setPlaying();
      expect(stats.status, PlaybackHealth.error);
    });

    test('setFallbackIndex notifica cambio de servidor activo', () {
      final stats = PlaybackStatsController();
      expect(stats.fallbackIndex, 0);
      stats.setFallbackIndex(2);
      expect(stats.fallbackIndex, 2);
    });

    test('setBackend del motor arranca en buffering', () {
      final stats = PlaybackStatsController();
      stats.setBackend(PlayerBackend.engineKotlin);
      expect(stats.backend, PlayerBackend.engineKotlin);
      expect(stats.status, PlaybackHealth.buffering);
    });
  });
}
