import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/state/calendar_provider.dart';

void main() {
  group('Home Flow and Translations Regression Tests', () {
    test('es.json contains all required live notification keys and VIVO status', () {
      final file = File('assets/translations/es.json');
      expect(file.existsSync(), isTrue);
      final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(jsonMap['calendar_status_live'], 'VIVO');
      expect(jsonMap['calendar_live_notification_single'], contains('{title}'));
      expect(jsonMap['calendar_live_notification_two'], contains('{t1}'));
      expect(jsonMap['calendar_live_notification_two'], contains('{t2}'));
      expect(jsonMap['calendar_live_notification_multiple'], contains('{count}'));
      expect(jsonMap['calendar_live_notification_multiple'], contains('{more}'));
      expect(jsonMap.containsKey('calendar_dialog_available_channels'), isFalse);
      expect(jsonMap.containsKey('calendar_dialog_tune_hint'), isFalse);
    });

    test('CalendarProvider formatLiveEventsMessage returns formatted text for all cases', () {
      final ev1 = CalendarEvent(
        id: '1',
        subscriptionId: 'sub1',
        title: 'Boca vs River',
        competition: 'LPF',
        startDateTime: DateTime.now(),
      );
      final ev2 = CalendarEvent(
        id: '2',
        subscriptionId: 'sub1',
        title: 'Racing vs Independiente',
        competition: 'LPF',
        startDateTime: DateTime.now(),
      );
      final ev3 = CalendarEvent(
        id: '3',
        subscriptionId: 'sub1',
        title: 'San Lorenzo vs Huracán',
        competition: 'LPF',
        startDateTime: DateTime.now(),
      );

      // Single
      final s1 = CalendarProvider.formatLiveEventsMessage([ev1]);
      expect(s1, contains('Boca vs River'));

      // Two
      final s2 = CalendarProvider.formatLiveEventsMessage([ev1, ev2]);
      expect(s2, contains('Boca vs River'));
      expect(s2, contains('Racing vs Independiente'));

      // Three
      final s3 = CalendarProvider.formatLiveEventsMessage([ev1, ev2, ev3]);
      expect(s3, contains('3 eventos'));
      expect(s3, contains('1 más'));
    });
  });
}
