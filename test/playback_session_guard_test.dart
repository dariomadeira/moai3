import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/player/playback/playback_session_guard.dart';

void main() {
  group('PlaybackSessionGuard', () {
    test('begin incrementa generación e invalida sesiones previas', () {
      final guard = PlaybackSessionGuard();
      final first = guard.begin();
      expect(guard.isCurrent(first), isTrue);

      final second = guard.begin();
      expect(guard.isCurrent(first), isFalse);
      expect(guard.isCurrent(second), isTrue);
    });

    test('dispose invalida todas las sesiones', () {
      final guard = PlaybackSessionGuard();
      final session = guard.begin();
      expect(guard.isCurrent(session), isTrue);

      guard.dispose();
      expect(guard.isCurrent(session), isFalse);
      expect(guard.isCurrent(guard.begin()), isFalse);
    });
  });
}

