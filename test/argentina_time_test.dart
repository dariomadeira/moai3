import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';
import 'package:moai3/state/calendar_provider.dart';

void main() {
  tearDown(() {
    ArgentinaTime.debugUtcNow = null;
  });

  test('el viernes 25 a las 21:11 ART sigue siendo viernes aunque en UTC sea sábado', () {
    ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 9, 26, 0, 11);

    final now = ArgentinaTime.now();
    expect(now.year, 2026);
    expect(now.month, 9);
    expect(now.day, 25);
    expect(now.hour, 21);
    expect(now.minute, 11);
    expect(now.weekday, DateTime.friday);

    final days = CalendarProvider.getDaysForWeekOffset(0);
    expect(days.first.day, 21);
    expect(days.first.weekday, DateTime.monday);
    expect(days[4].day, 25);
    expect(days[4].weekday, DateTime.friday);
    expect(days.last.day, 27);
    expect(days.last.weekday, DateTime.sunday);
  });

  test('un partido 00:15 UTC cae el viernes 21:15 en Argentina y es de hoy', () {
    ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 9, 26, 0, 11);

    final events = SportsScheduleService.parseCategories({
      'Torneo LPF': [
        {'time': '00:15', 'event': 'Lanus - Estudiantes L.P.'},
      ],
    }, DateTime.utc(2026, 9, 26, 0, 11));

    expect(events, hasLength(1));
    final event = events.first;
    expect(event.startDateTime, DateTime.utc(2026, 9, 26, 0, 15));
    expect(event.formattedDate, '25/09/2026');
    expect(event.formattedTime, '21:15');
    expect(event.isToday, isTrue);
    expect(event.status, CalendarEventStatus.upcoming);
  });

  test('fromCivil arma el instante UTC de una hora de Argentina', () {
    expect(
      ArgentinaTime.fromCivil(2026, 9, 25, 21, 15),
      DateTime.utc(2026, 9, 26, 0, 15),
    );
    final civil = ArgentinaTime.toCivil(ArgentinaTime.fromCivil(2026, 9, 25, 21, 15));
    expect(civil.day, 25);
    expect(civil.hour, 21);
    expect(civil.minute, 15);
  });
}
