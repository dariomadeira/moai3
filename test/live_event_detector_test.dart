import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/live_event_detector.dart';

void main() {
  final now = DateTime.now().toUtc();

  CalendarEvent event(String id, Duration fromNow) => CalendarEvent(
    id: id,
    title: 'Partido $id',
    subscriptionId: 'football_lpf',
    competition: 'Liga',
    startDateTime: now.add(fromNow),
  );

  group('LiveEventDetector', () {
    test('la primera carga no avisa lo que ya estaba en curso', () {
      final detector = LiveEventDetector();
      final started = event('a', const Duration(minutes: -10));
      final later = event('b', const Duration(hours: 2));
      expect(detector.prime([started, later]), isTrue);
      expect(detector.prime([started]), isFalse);
      expect(detector.takeNew([started, later]), isEmpty);
    });

    test('avisa una sola vez al entrar en la ventana', () {
      final detector = LiveEventDetector()..prime(const []);
      final started = event('a', const Duration(minutes: -1));
      expect(detector.takeNew([started]).map((e) => e.id), ['a']);
      expect(detector.takeNew([started]), isEmpty);
    });

    test('la anticipación adelanta el aviso', () {
      final detector = LiveEventDetector()..prime(const []);
      final soon = event('a', const Duration(minutes: 10));
      expect(detector.takeNew([soon]), isEmpty);
      detector.leadMinutes = 15;
      expect(detector.takeNew([soon]).map((e) => e.id), ['a']);
    });
  });
}
