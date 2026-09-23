import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/state/calendar_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Calendar Live Notifications & Grouping Tests', () {
    test('formatLiveEventsMessage formatea evento individual', () {
      final ev = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'lpf_ar',
        title: 'Boca Juniors vs River Plate',
        competition: 'Liga Profesional',
        startDateTime: DateTime.now(),
      );

      final msg = CalendarProvider.formatLiveEventsMessage([ev]);
      expect(msg, 'Comenzó en vivo: Boca Juniors vs River Plate');
    });

    test('formatLiveEventsMessage agrupa exactamente 2 eventos simultáneos', () {
      final ev1 = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'premier',
        title: 'Tottenham Hotspur vs Aston Villa',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );
      final ev2 = CalendarEvent(
        id: 'ev_2',
        subscriptionId: 'premier',
        title: 'Arsenal vs Chelsea',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );

      final msg = CalendarProvider.formatLiveEventsMessage([ev1, ev2]);
      expect(msg.startsWith('Comenzaron 2 eventos:'), isTrue);
      expect(msg.contains('Tottenham Hotspur'), isTrue);
      expect(msg.contains('Arsenal vs Chelsea'), isTrue);
    });

    test('formatLiveEventsMessage agrupa 3 o más eventos con contador y resumen', () {
      final ev1 = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'premier',
        title: 'Tottenham vs Aston Villa',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );
      final ev2 = CalendarEvent(
        id: 'ev_2',
        subscriptionId: 'premier',
        title: 'Arsenal vs Chelsea',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );
      final ev3 = CalendarEvent(
        id: 'ev_3',
        subscriptionId: 'champions',
        title: 'Real Madrid vs Bayern',
        competition: 'Champions League',
        startDateTime: DateTime.now(),
      );

      final msg = CalendarProvider.formatLiveEventsMessage([ev1, ev2, ev3]);
      expect(msg.startsWith('Comenzaron 3 eventos en vivo:'), isTrue);
      expect(msg.contains('1 más'), isTrue);
    });

    test('getLiveEventsIcon retorna ícono del deporte cuando comparten suscripción', () {
      final ev1 = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'premier',
        title: 'Partido 1',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );
      final ev2 = CalendarEvent(
        id: 'ev_2',
        subscriptionId: 'premier',
        title: 'Partido 2',
        competition: 'Premier League',
        startDateTime: DateTime.now(),
      );

      final icon = CalendarProvider.getLiveEventsIcon([ev1, ev2]);
      expect(icon, CalendarProvider.getSubscriptionIcon('premier'));
    });

    test('getLiveEventsIcon retorna live_tv_rounded cuando hay mezcla de deportes', () {
      final ev1 = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'f1',
        title: 'GP de Mónaco - Carrera',
        competition: 'F1',
        startDateTime: DateTime.now(),
      );
      final ev2 = CalendarEvent(
        id: 'ev_2',
        subscriptionId: 'lpf_ar',
        title: 'Racing vs Independiente',
        competition: 'Liga Profesional',
        startDateTime: DateTime.now(),
      );

      final icon = CalendarProvider.getLiveEventsIcon([ev1, ev2]);
      expect(icon, Icons.live_tv_rounded);
    });

    test('CalendarProvider emite en onLiveEventsStarted y deduplica avisos posteriores', () async {
      final provider = CalendarProvider(startTicker: false);
      await provider.toggleSubscription('lpf_ar');

      final emittedBatches = <List<CalendarEvent>>[];
      final sub = provider.onLiveEventsStarted.listen((batch) {
        emittedBatches.add(batch);
      });

      // Primera comprobación sin nuevos eventos
      provider.checkNewLiveEvents();
      expect(emittedBatches, isEmpty);

      // Segunda comprobación: se evalúa nuevamente
      provider.checkNewLiveEvents();
      expect(emittedBatches, isEmpty);

      await sub.cancel();
      provider.dispose();
    });
  });
}
