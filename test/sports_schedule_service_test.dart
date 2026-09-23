import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';

void main() {
  group('SportsScheduleService Tests', () {
    test('Deduplica eventos repetidos en diferentes categorías (WNBA, Basketball, NBA)', () {
      final mockCategories = {
        'WNBA 🏀': [
          {'time': '23:30', 'event': '🏀 WNBA : Washington Mystics W 🇺🇸 vs Connecticut Sun W 🇺🇸'},
        ],
        'Basketball 🏀': [
          {'time': '23:30', 'event': '🏀 Washington Mystics vs Connecticut Sun'},
          {'time': '23:30', 'event': '🏀 Connecticut Sun vs. Washington Mystics'},
        ],
        '🏀 Basketball — NBA': [
          {'time': '23:30', 'event': 'Connecticut Sun vs Washington Mystics'},
        ],
      };

      final baseUtc = DateTime.utc(2026, 9, 23, 0, 25);
      final events = SportsScheduleService.parseCategories(mockCategories, baseUtc);

      // Debe quedar exactamente 1 solo evento único
      expect(events.length, 1);
      expect(events.first.title.toLowerCase().contains('washington mystics'), isTrue);
      expect(events.first.title.toLowerCase().contains('connecticut sun'), isTrue);
    });

    test('Deduplica partidos de NFL repetidos con distinto orden de equipos', () {
      final mockCategories = {
        'NFL': [
          {'time': '00:15', 'event': 'NFL : New York Giants vs Los Angeles Rams'},
          {'time': '00:15', 'event': 'Los Angeles Rams - New York Giants'},
        ],
      };

      final baseUtc = DateTime.utc(2026, 9, 23, 0, 25);
      final events = SportsScheduleService.parseCategories(mockCategories, baseUtc);

      // Debe quedar exactamente 1 solo evento único
      expect(events.length, 1);
      expect(events.first.subscriptionId, 'nfl');
    });

    test('Parsea horario UTC a horario local correctamente sin desfasar el día', () {
      final mockCategories = {
        'Torneo LPF': [
          {'time': '00:15', 'event': 'Lanus - Estudiantes L.P.'},
        ],
      };

      // Si en UTC son las 00:25 del 23 de Septiembre (en Argentina UTC-3 son las 21:25 del 22 de Septiembre)
      final baseUtc = DateTime.utc(2026, 9, 23, 0, 25);
      final events = SportsScheduleService.parseCategories(mockCategories, baseUtc);

      expect(events.length, 1);
      final ev = events.first;
      // En UTC el partido es a las 00:15 del 23 de Septiembre.
      // En hora local (UTC-3), debe ser a las 21:15 del 22 de Septiembre.
      final expectedLocal = DateTime.utc(2026, 9, 23, 0, 15).toLocal();
      expect(ev.startDateTime, expectedLocal);
    });

    test('Extrae channelHints desde el array de channels de la API de DaddyLive', () {
      final mockCategories = {
        'Fútbol Argentino LPF': [
          {
            'time': '21:00',
            'event': 'Boca Juniors vs River Plate',
            'channels': [
              {
                'channel_name': 'Link - 1',
                'url': 'https://daddylive.li/player/embed.php?id=1027',
              },
              {
                'channel_name': 'Link - 2',
                'url': 'https://daddylive.li/player/embed.php?id=1201&source=tv2',
              },
              {
                'channel_name': 'Direct Channel',
                'id': '505',
              },
            ],
          },
        ],
      };

      final baseUtc = DateTime.utc(2026, 9, 23, 20, 00);
      final events = SportsScheduleService.parseCategories(mockCategories, baseUtc);

      expect(events.length, 1);
      final ev = events.first;
      expect(ev.channelHints, containsAll(['1027', '1201', '505']));
    });
  });
}
