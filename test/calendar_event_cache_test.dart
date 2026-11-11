import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/live_event_detector.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CalendarEvent event(String id, String sub, DateTime start) => CalendarEvent(
    id: id,
    subscriptionId: sub,
    title: id,
    competition: 'x',
    startDateTime: start,
  );

  Future<CalendarProvider> ready() async {
    SharedPreferences.setMockInitialValues({});
    final provider = CalendarProvider(startTicker: false);
    addTearDown(provider.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    while (provider.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return provider;
  }

  group('eventos por día guardados', () {
    final start = DateTime.utc(2026, 11, 10, 1); // 9/11 22:00 en Argentina
    final monday = DateTime(2026, 11, 9);
    final tuesday = DateTime(2026, 11, 10);

    tearDown(() => ArgentinaTime.offsetHours = -3);

    test('al cambiar las suscripciones se recalculan', () async {
      final provider = await ready();
      provider.debugSetEvents([event('a', 'f1', start)]);
      expect(provider.getEventsForDay(monday), isEmpty);

      await provider.toggleSubscription('f1');
      expect(provider.getEventsForDay(monday), hasLength(1));

      await provider.toggleSubscription('f1');
      expect(provider.getEventsForDay(monday), isEmpty);
    });

    test('al llegar eventos nuevos se recalculan', () async {
      final provider = await ready();
      await provider.toggleSubscription('f1');
      provider.debugSetEvents([event('a', 'f1', start)]);
      expect(provider.getEventsForDay(monday), hasLength(1));

      provider.debugSetEvents(const []);
      expect(provider.getEventsForDay(monday), isEmpty);
    });

    test('al cambiar la zona horaria el evento cambia de día', () async {
      final provider = await ready();
      await provider.toggleSubscription('f1');
      provider.debugSetEvents([event('a', 'f1', start)]);
      expect(provider.getEventsForDay(monday), hasLength(1));

      ArgentinaTime.offsetHours = 0;
      expect(provider.getEventsForDay(monday), isEmpty);
      expect(provider.getEventsForDay(tuesday), hasLength(1));
    });
  });

  test('sólo se piden ligas de ESPN, una descarga por mes', () {
    expect(
      SportsScheduleService.loadKeys(
        ['f1', 'nba', 'lpf_ar'],
        ['202610', '202611'],
      ),
      ['nba|202610', 'nba|202611', 'lpf_ar|202610', 'lpf_ar|202611'],
    );
  });

  test('una liga recién activada no avisa lo que ya empezó', () {
    final now = DateTime.now().toUtc();
    final started = event(
      'ya',
      'nba',
      now.subtract(const Duration(minutes: 10)),
    );
    final detector = LiveEventDetector()..prime(const []);
    detector.markStarted([started]);
    expect(detector.takeNew([started]), isEmpty);
  });
}
