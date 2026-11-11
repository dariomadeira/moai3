import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';

/// Un evento con la forma de un `scoreboard` de ESPN (sólo lo que se lee).
Map<String, dynamic> _espnEvent({
  required String id,
  required String date,
  String home = 'Liverpool',
  String away = 'Arsenal',
  String state = 'pre',
  String statusName = 'STATUS_SCHEDULED',
  bool timeValid = true,
}) => {
  'id': id,
  'date': date,
  'name': '$away at $home',
  'status': {
    'type': {'name': statusName, 'state': state},
  },
  'competitions': [
    {
      'date': date,
      'timeValid': timeValid,
      'competitors': [
        {
          'homeAway': 'home',
          'team': {'displayName': home},
        },
        {
          'homeAway': 'away',
          'team': {'displayName': away},
        },
      ],
    },
  ],
};

void main() {
  tearDown(() => ArgentinaTime.debugUtcNow = null);

  group('SportsScheduleService.parseScoreboard', () {
    test(
      'arma el partido "Local vs Visitante" con la liga y quién lo pasa',
      () {
        final events = SportsScheduleService.parseScoreboard('premier', {
          'events': [_espnEvent(id: '1', date: '2026-11-02T20:00Z')],
        });

        expect(events, hasLength(1));
        final ev = events.single;
        expect(ev.id, 'espn_premier_1');
        expect(ev.subscriptionId, 'premier');
        expect(ev.title, 'Liverpool vs Arsenal');
        expect(ev.competition, 'Premier League');
        expect(ev.startDateTime, DateTime.utc(2026, 11, 2, 20));
        expect(ev.sessionType, LocaleKeys.calendar_session_match);
        // Canales de Argentina, no los de EE. UU. que informa ESPN.
        expect(ev.broadcaster, 'ESPN / Disney+');
        expect(ev.channelHints, isEmpty);
      },
    );

    test('la hora va en UTC y en Argentina cae el día anterior', () {
      ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 9, 26, 0, 11);
      final events = SportsScheduleService.parseScoreboard('lpf_ar', {
        'events': [
          _espnEvent(
            id: '7',
            date: '2026-09-26T00:15Z',
            home: 'Lanús',
            away: 'Estudiantes',
          ),
        ],
      });

      final ev = events.single;
      expect(ev.formattedDate, '25/09/2026');
      expect(ev.formattedTime, '21:15');
      expect(ev.isToday, isTrue);
      expect(ev.status, CalendarEventStatus.upcoming);
    });

    test('toma el estado de ESPN: terminado y en vivo', () {
      ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 11, 2, 21);
      final events = SportsScheduleService.parseScoreboard('nba', {
        'events': [
          _espnEvent(
            id: 'fin',
            date: '2026-11-02T20:00Z',
            state: 'post',
            statusName: 'STATUS_FINAL',
          ),
          _espnEvent(
            id: 'vivo',
            date: '2026-11-02T20:30Z',
            state: 'in',
            statusName: 'STATUS_IN_PROGRESS',
          ),
        ],
      });

      final byId = {for (final e in events) e.id: e};
      expect(byId['espn_nba_fin']!.status, CalendarEventStatus.finished);
      expect(byId['espn_nba_vivo']!.status, CalendarEventStatus.live);
    });

    test('deja afuera los postergados y suspendidos', () {
      final events = SportsScheduleService.parseScoreboard('lpf_ar', {
        'events': [
          _espnEvent(id: 'ok', date: '2026-11-08T21:00Z'),
          _espnEvent(
            id: 'post',
            date: '2026-11-08T21:00Z',
            statusName: 'STATUS_POSTPONED',
          ),
          _espnEvent(
            id: 'canc',
            date: '2026-11-08T21:00Z',
            statusName: 'STATUS_CANCELED',
          ),
        ],
      });

      expect(events.map((e) => e.id), ['espn_lpf_ar_ok']);
    });

    test('sin hora confirmada queda en su día, "por empezar" y sin hora', () {
      // Domingo 8 a la mañana en Argentina; ESPN pone 03:00Z de relleno.
      ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 11, 8, 12);
      final events = SportsScheduleService.parseScoreboard('lpf_ar', {
        'events': [
          _espnEvent(id: 'tbd', date: '2026-11-08T03:00Z', timeValid: false),
        ],
      });

      final ev = events.single;
      expect(ev.timeConfirmed, isFalse);
      expect(ev.formattedDate, '08/11/2026');
      expect(ev.formattedTime, LocaleKeys.calendar_time_tbd);
      // Pasó la hora de relleno, pero no se sabe si empezó.
      expect(ev.status, CalendarEventStatus.upcoming);

      // Al día siguiente ya terminó.
      ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 11, 9, 12);
      expect(ev.status, CalendarEventStatus.finished);
    });

    test('los de hora confirmada van antes que los "a confirmar" del día', () {
      final events = SportsScheduleService.parseScoreboard('lpf_ar', {
        'events': [
          _espnEvent(id: 'tbd', date: '2026-11-08T03:00Z', timeValid: false),
          _espnEvent(id: 'ok', date: '2026-11-08T21:00Z'),
        ],
      })..sort(CalendarEvent.compareByStatusAndDate);

      expect(events.map((e) => e.id), ['espn_lpf_ar_ok', 'espn_lpf_ar_tbd']);
    });

    test('sin eventos o con datos rotos no falla', () {
      expect(SportsScheduleService.parseScoreboard('nfl', {}), isEmpty);
      expect(
        SportsScheduleService.parseScoreboard('nfl', {
          'events': [
            {'id': 'x'},
            'basura',
          ],
        }),
        isEmpty,
      );
    });
  });

  group('SportsScheduleService.monthsToFetch', () {
    test('a mitad de mes basta un mes', () {
      // Lunes 16: de la semana pasada (9) a la próxima (29).
      expect(SportsScheduleService.monthsToFetch(DateTime(2026, 11, 16)), [
        '202611',
      ]);
    });

    test('a principio de mes suma el anterior', () {
      // Lunes 2 de noviembre: la semana pasada empieza el 26 de octubre.
      expect(SportsScheduleService.monthsToFetch(DateTime(2026, 11, 2)), [
        '202610',
        '202611',
      ]);
    });

    test('a fin de año pasa al año siguiente', () {
      // Lunes 28 de diciembre: la semana próxima termina el 10 de enero.
      expect(SportsScheduleService.monthsToFetch(DateTime(2026, 12, 28)), [
        '202612',
        '202701',
      ]);
    });
  });

  group('SportsScheduleService.monthsForWeek', () {
    test('una semana dentro del mes pide ese mes', () {
      expect(SportsScheduleService.monthsForWeek(DateTime(2026, 11, 16)), [
        '202611',
      ]);
    });

    test('una semana que cruza de mes pide los dos', () {
      // Lunes 30 de noviembre a domingo 6 de diciembre.
      expect(SportsScheduleService.monthsForWeek(DateTime(2026, 11, 30)), [
        '202611',
        '202612',
      ]);
    });

    test('el lunes 1 suma el mes anterior por el día de margen', () {
      // ESPN agrupa por la fecha de EE. UU.: el domingo a la noche anterior
      // puede ser parte de la semana en Argentina.
      expect(SportsScheduleService.monthsForWeek(DateTime(2027, 2)), [
        '202701',
        '202702',
      ]);
    });

    test('un día que no es lunes usa el lunes de su semana', () {
      expect(
        SportsScheduleService.monthsForWeek(DateTime(2026, 11, 19)),
        SportsScheduleService.monthsForWeek(DateTime(2026, 11, 16)),
      );
    });
  });

  test('cada suscripción de deportes tiene su liga en ESPN (sin MotoGP)', () {
    expect(SportsScheduleService.leagues.keys, [
      'lpf_ar',
      'premier',
      'champions',
      'nfl',
      'nba',
    ]);
  });
}
