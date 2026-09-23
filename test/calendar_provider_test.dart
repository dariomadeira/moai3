import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/f1_calendar_service.dart';
import 'package:moai3/state/calendar_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalendarProvider Tests', () {
    test('Inicializa sin suscripciones activas por defecto en primera instalación', () async {
      final provider = CalendarProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(provider.subscriptions.isNotEmpty, isTrue);
      final hasAnySubscribed = provider.subscriptions.any((s) => s.isSubscribed);
      expect(hasAnySubscribed, isFalse);
      expect(provider.subscribedEvents, isEmpty);
    });

    test('Alternar suscripción cambia el estado y notifica', () async {
      final provider = CalendarProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      final motogpBefore = provider.subscriptions.firstWhere((s) => s.id == 'motogp');
      expect(motogpBefore.isSubscribed, isFalse);

      await provider.toggleSubscription('motogp');

      final motogpAfter = provider.subscriptions.firstWhere((s) => s.id == 'motogp');
      expect(motogpAfter.isSubscribed, isTrue);
    });

    test('Eventos de hoy y cálculo de todayEventCount', () {
      final now = DateTime.now();
      final todayEvent = CalendarEvent(
        id: 'test_1',
        subscriptionId: 'f1',
        title: 'Práctica Libre',
        competition: 'F1',
        startDateTime: now,
        status: CalendarEventStatus.upcoming,
      );

      expect(todayEvent.isToday, isTrue);
      expect(todayEvent.formattedTime.contains(':'), isTrue);

      final todayFinished = CalendarEvent(
        id: 'test_2',
        subscriptionId: 'f1',
        title: 'Práctica 1',
        competition: 'F1',
        startDateTime: now.subtract(const Duration(hours: 4)),
      );
      expect(todayFinished.isToday, isTrue);
      expect(todayFinished.status, CalendarEventStatus.finished);
    });

    test('Eventos pasados calculan status finalizado', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final pastEvent = CalendarEvent(
        id: 'test_past',
        subscriptionId: 'f1',
        title: 'Carrera Pasada',
        competition: 'F1',
        startDateTime: past,
      );

      expect(pastEvent.isToday, isFalse);
      expect(pastEvent.status, CalendarEventStatus.finished);
      expect(pastEvent.statusPriority, 2);
    });

    test('Eventos en vivo calculan status live y prioridad 0', () {
      final now = DateTime.now().subtract(const Duration(minutes: 30));
      final liveEvent = CalendarEvent(
        id: 'test_live',
        subscriptionId: 'f1',
        title: 'Carrera En Vivo',
        competition: 'F1',
        startDateTime: now,
      );

      expect(liveEvent.status, CalendarEventStatus.live);
      expect(liveEvent.statusPriority, 0);
    });

    test('Eventos futuros calculan status upcoming y prioridad 1', () {
      final future = DateTime.now().add(const Duration(hours: 3));
      final futureEvent = CalendarEvent(
        id: 'test_future',
        subscriptionId: 'f1',
        title: 'Carrera Futura',
        competition: 'F1',
        startDateTime: future,
      );

      expect(futureEvent.status, CalendarEventStatus.upcoming);
      expect(futureEvent.statusPriority, 1);
    });

    test('estimatedDuration adapta el ciclo de vida por deporte y sesión', () {
      final now = DateTime.now();

      // 1. Fútbol: 115 min
      final soccerMatch = CalendarEvent(
        id: 'soc_1',
        subscriptionId: 'lpf_ar',
        title: 'Boca vs River',
        competition: 'Liga Profesional',
        startDateTime: now.subtract(const Duration(minutes: 90)),
      );
      expect(soccerMatch.estimatedDuration.inMinutes, 115);
      expect(soccerMatch.status, CalendarEventStatus.live);

      final soccerFinished = soccerMatch.copyWith(
        startDateTime: now.subtract(const Duration(minutes: 125)),
      );
      expect(soccerFinished.status, CalendarEventStatus.finished);

      // 2. NFL: 210 min (3.5 horas)
      final nflGame = CalendarEvent(
        id: 'nfl_1',
        subscriptionId: 'nfl',
        title: 'Cowboys vs Eagles',
        competition: 'NFL',
        startDateTime: now.subtract(const Duration(minutes: 150)), // 2.5 horas
      );
      expect(nflGame.estimatedDuration.inMinutes, 210);
      expect(nflGame.status, CalendarEventStatus.live); // Sigue en vivo

      final nflFinished = nflGame.copyWith(
        startDateTime: now.subtract(const Duration(minutes: 220)),
      );
      expect(nflFinished.status, CalendarEventStatus.finished);

      // 3. F1 Qualy: 75 min
      final f1Qualy = CalendarEvent(
        id: 'f1_q',
        subscriptionId: 'f1',
        title: 'GP de Mónaco — Clasificación',
        competition: 'F1',
        sessionType: 'Qualy',
        startDateTime: now.subtract(const Duration(minutes: 60)),
      );
      expect(f1Qualy.estimatedDuration.inMinutes, 75);
      expect(f1Qualy.status, CalendarEventStatus.live);

      final f1QualyFinished = f1Qualy.copyWith(
        startDateTime: now.subtract(const Duration(minutes: 85)),
      );
      expect(f1QualyFinished.status, CalendarEventStatus.finished);
    });

    test('compareByStatusAndDate ordena: LIVE -> UPCOMING -> FINISHED', () {
      final now = DateTime.now();
      final finishedEvent = CalendarEvent(
        id: '1',
        subscriptionId: 'sub',
        title: 'Pasado',
        competition: 'Comp',
        startDateTime: now.subtract(const Duration(hours: 5)),
      );
      final liveEvent = CalendarEvent(
        id: '2',
        subscriptionId: 'sub',
        title: 'En Vivo',
        competition: 'Comp',
        startDateTime: now.subtract(const Duration(minutes: 15)),
      );
      final upcomingEvent = CalendarEvent(
        id: '3',
        subscriptionId: 'sub',
        title: 'Futuro',
        competition: 'Comp',
        startDateTime: now.add(const Duration(hours: 2)),
      );

      final list = [finishedEvent, upcomingEvent, liveEvent];
      list.sort(CalendarEvent.compareByStatusAndDate);

      expect(list[0].id, '2'); // LIVE
      expect(list[1].id, '3'); // UPCOMING
      expect(list[2].id, '1'); // FINISHED
    });


    test('F1 no tiene eventos en fines de semana sin Gran Premio', () async {
      final provider = CalendarProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      await provider.toggleSubscription('f1');
      await provider.refreshEvents(force: true);

      // 20 Sep 2026 (Hoy) NO hubo Gran Premio de F1
      final todayEvents = provider.getEventsForDay(DateTime(2026, 9, 20));
      final f1Today = todayEvents.where((e) => e.subscriptionId == 'f1').toList();
      expect(f1Today, isEmpty, reason: 'Hoy 20 Sep 2026 no debe haber F1');

      // Próxima semana sí hay Gran Premio de Azerbaiyán
      final nextWeekF1 = provider.subscribedEvents.where(
        (e) => e.subscriptionId == 'f1' && e.startDateTime.isAfter(DateTime(2026, 9, 22)),
      ).toList();
      expect(nextWeekF1, isNotEmpty, reason: 'La próxima semana debe tener el GP de Azerbaiyán');

      // Domingo 27 de Septiembre es la Carrera
      final sundayEvents = provider.getEventsForDay(DateTime(2026, 9, 27));
      final sundayRace = sundayEvents.where((e) => e.subscriptionId == 'f1' && e.sessionType == 'Carrera').toList();
      expect(sundayRace, isNotEmpty, reason: 'La carrera de F1 debe estar el Domingo 27 de Septiembre');

      // Sábado 26 de Septiembre es la Clasificación, no la Carrera
      final saturdayEvents = provider.getEventsForDay(DateTime(2026, 9, 26));
      final saturdayRace = saturdayEvents.where((e) => e.subscriptionId == 'f1' && e.sessionType == 'Carrera').toList();
      expect(saturdayRace, isEmpty, reason: 'La carrera de F1 NO debe estar el Sábado');
      final saturdayQualy = saturdayEvents.where((e) => e.subscriptionId == 'f1' && e.sessionType == 'Qualy').toList();
      expect(saturdayQualy, isNotEmpty, reason: 'El Sábado 26 debe tener la Clasificación');
    });

    test('F1 parser corrige desfase de 1 día de la API para que la carrera sea en Domingo', () {
      final mockRaceJson = {
        'season': '2026',
        'round': '15',
        'raceName': 'Azerbaijan Grand Prix',
        'Circuit': {'circuitName': 'Baku City Circuit'},
        'date': '2026-09-26', // Sábado en Ergast provisional
        'time': '11:00:00Z',
        'Qualifying': {'date': '2026-09-25', 'time': '12:00:00Z'},
        'FirstPractice': {'date': '2026-09-24', 'time': '08:30:00Z'},
      };

      final events = F1CalendarService.parseRacesForTest([mockRaceJson]);
      final race = events.firstWhere((e) => e.sessionType == 'Carrera');
      final qualy = events.firstWhere((e) => e.sessionType == 'Qualy');
      final fp1 = events.firstWhere((e) => e.sessionType == 'Práctica 1');

      // Carrera debe ser Domingo (weekday 7), día 27
      expect(race.startDateTime.weekday, DateTime.sunday);
      expect(race.startDateTime.day, 27);

      // Clasificación debe ser Sábado (weekday 6), día 26
      expect(qualy.startDateTime.weekday, DateTime.saturday);
      expect(qualy.startDateTime.day, 26);

      // Práctica debe ser Viernes (weekday 5), día 25
      expect(fp1.startDateTime.weekday, DateTime.friday);
      expect(fp1.startDateTime.day, 25);
    });
  });
}

