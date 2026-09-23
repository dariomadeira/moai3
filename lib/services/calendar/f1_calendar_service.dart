import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/calendar_event.dart';

/// Servicio para consultar el calendario oficial de Fórmula 1 vía API pública Jolpica/Ergast.
class F1CalendarService {
  static const String endpoint = 'https://api.jolpi.ca/ergast/f1/current.json';

  static Future<List<CalendarEvent>> fetchF1Events() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(endpoint));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;

        final mrData = data['MRData'] as Map<String, dynamic>?;
        final raceTable = mrData?['RaceTable'] as Map<String, dynamic>?;
        final races = raceTable?['Races'] as List<dynamic>? ?? [];

        if (races.isNotEmpty) {
          final parsed = _parseRaces(races);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } else {
        debugPrint('[F1CalendarService] HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[F1CalendarService] Error al obtener calendario F1: $e');
    }

    // Si la API falla o estamos offline, recurrir al calendario oficial de respaldo
    return _getFallback2026Events();
  }

  @visibleForTesting
  static List<CalendarEvent> parseRacesForTest(List<dynamic> races) => _parseRaces(races);

  static List<CalendarEvent> _parseRaces(List<dynamic> races) {
    final List<CalendarEvent> events = [];

    for (final r in races) {
      if (r is! Map<String, dynamic>) continue;
      final raceName = r['raceName'] as String? ?? 'Gran Premio';
      final circuit = (r['Circuit'] as Map<String, dynamic>?)?['circuitName'] as String? ?? '';
      final round = r['round'] as String? ?? '';
      final compName = circuit.isNotEmpty ? 'F1 · $circuit' : 'Fórmula 1';

      // Corrección de desfase de 1 día: En el borrador de la API Jolpica/Ergast,
      // las fechas de Azerbaiyán (round 15) vienen cargadas un día antes (Jue-Sáb en vez de Vie-Dom).
      // Se corrige para que las Prácticas sean el Viernes, Clasificación el Sábado y la Carrera el Domingo.
      final bool needsSundayCorrection =
          (round == '15' || raceName.toLowerCase().contains('azerbaijan'));
      final sessionOffset = needsSundayCorrection ? const Duration(days: 1) : Duration.zero;

      // 1. Práctica Libre 1
      _addSessionIfPresent(
        events: events,
        sessionMap: r['FirstPractice'] as Map<String, dynamic>?,
        id: 'f1_r_${round}_fp1',
        title: '$raceName — Práctica Libre 1',
        competition: compName,
        sessionType: 'Práctica 1',
        duration: const Duration(hours: 1),
        offset: sessionOffset,
      );

      // 2. Práctica Libre 2 (o Sprint Shootout)
      _addSessionIfPresent(
        events: events,
        sessionMap: (r['SprintQualifying'] ?? r['SecondPractice']) as Map<String, dynamic>?,
        id: 'f1_r_${round}_fp2',
        title: r['SprintQualifying'] != null
            ? '$raceName — Clasificación Sprint'
            : '$raceName — Práctica Libre 2',
        competition: compName,
        sessionType: r['SprintQualifying'] != null ? 'Sprint Shootout' : 'Práctica 2',
        duration: const Duration(minutes: 45),
        offset: sessionOffset,
      );

      // 3. Práctica Libre 3 (si existe)
      _addSessionIfPresent(
        events: events,
        sessionMap: r['ThirdPractice'] as Map<String, dynamic>?,
        id: 'f1_r_${round}_fp3',
        title: '$raceName — Práctica Libre 3',
        competition: compName,
        sessionType: 'Práctica 3',
        duration: const Duration(hours: 1),
        offset: sessionOffset,
      );

      // 4. Sprint (si aplica)
      _addSessionIfPresent(
        events: events,
        sessionMap: r['Sprint'] as Map<String, dynamic>?,
        id: 'f1_r_${round}_sprint',
        title: '$raceName — Carrera Sprint',
        competition: compName,
        sessionType: 'Sprint',
        duration: const Duration(minutes: 45),
        offset: sessionOffset,
      );

      // 5. Clasificación
      _addSessionIfPresent(
        events: events,
        sessionMap: r['Qualifying'] as Map<String, dynamic>?,
        id: 'f1_r_${round}_qualy',
        title: '$raceName — Clasificación',
        competition: compName,
        sessionType: 'Qualy',
        duration: const Duration(hours: 1),
        offset: sessionOffset,
      );

      // 6. Gran Premio (Carrera Principal siempre en Domingo)
      final raceDate = r['date'] as String?;
      final raceTime = r['time'] as String? ?? '14:00:00Z';
      if (raceDate != null) {
        var dt = _parseUtcDateTime(raceDate, raceTime);
        if (dt != null) {
          if (needsSundayCorrection) {
            dt = dt.add(const Duration(days: 1));
          }
          events.add(CalendarEvent(
            id: 'f1_r_${round}_race',
            subscriptionId: 'f1',
            title: '$raceName — Gran Premio',
            competition: compName,
            startDateTime: dt,
            sessionType: 'Carrera',
            broadcaster: 'Fox Sports / Disney+',
            status: _calculateStatus(dt, const Duration(hours: 2)),
          ));
        }
      }
    }

    return events;
  }

  static void _addSessionIfPresent({
    required List<CalendarEvent> events,
    required Map<String, dynamic>? sessionMap,
    required String id,
    required String title,
    required String competition,
    required String sessionType,
    required Duration duration,
    Duration offset = Duration.zero,
  }) {
    if (sessionMap == null) return;
    final date = sessionMap['date'] as String?;
    final time = sessionMap['time'] as String? ?? '12:00:00Z';
    if (date == null) return;

    var dt = _parseUtcDateTime(date, time);
    if (dt == null) return;
    if (offset != Duration.zero) {
      dt = dt.add(offset);
    }

    events.add(CalendarEvent(
      id: id,
      subscriptionId: 'f1',
      title: title,
      competition: competition,
      startDateTime: dt,
      sessionType: sessionType,
      broadcaster: 'Fox Sports / Disney+',
      status: _calculateStatus(dt, duration),
    ));
  }

  static DateTime? _parseUtcDateTime(String date, String time) {
    try {
      final cleanTime = time.endsWith('Z') ? time : '${time}Z';
      final iso = '${date}T$cleanTime';
      return DateTime.parse(iso).toLocal();
    } catch (_) {
      try {
        return DateTime.parse(date).toLocal();
      } catch (_) {
        return null;
      }
    }
  }

  static CalendarEventStatus _calculateStatus(DateTime start, Duration duration) {
    final now = DateTime.now();
    final end = start.add(duration);
    if (now.isBefore(start)) {
      return CalendarEventStatus.upcoming;
    } else if (now.isAfter(end)) {
      return CalendarEventStatus.finished;
    } else {
      return CalendarEventStatus.live;
    }
  }

  /// Calendario oficial de respaldo para la temporada 2026.
  /// Evita inventar carreras los fines de semana que no hay fecha de F1.
  static List<CalendarEvent> _getFallback2026Events() {
    final events = <CalendarEvent>[];

    void addGp({
      required String round,
      required String raceName,
      required String circuit,
      required DateTime fpDate,
      required DateTime qualyDate,
      required DateTime raceDate,
    }) {
      events.add(CalendarEvent(
        id: 'f1_r_${round}_fp1',
        subscriptionId: 'f1',
        title: '$raceName — Prácticas Libres',
        competition: 'F1 · $circuit',
        startDateTime: fpDate,
        sessionType: 'Prácticas',
        broadcaster: 'Fox Sports / Disney+',
        status: _calculateStatus(fpDate, const Duration(hours: 2)),
      ));
      events.add(CalendarEvent(
        id: 'f1_r_${round}_qualy',
        subscriptionId: 'f1',
        title: '$raceName — Clasificación',
        competition: 'F1 · $circuit',
        startDateTime: qualyDate,
        sessionType: 'Qualy',
        broadcaster: 'Fox Sports / Disney+',
        status: _calculateStatus(qualyDate, const Duration(hours: 1)),
      ));
      events.add(CalendarEvent(
        id: 'f1_r_${round}_race',
        subscriptionId: 'f1',
        title: '$raceName — Gran Premio',
        competition: 'F1 · $circuit',
        startDateTime: raceDate,
        sessionType: 'Carrera',
        broadcaster: 'Fox Sports / Disney+',
        status: _calculateStatus(raceDate, const Duration(hours: 2)),
      ));
    }

    // GP 14: España (13 Sep 2026) - Semana pasada
    addGp(
      round: '14',
      raceName: 'Gran Premio de España',
      circuit: 'Madring',
      fpDate: DateTime(2026, 9, 11, 8, 30),
      qualyDate: DateTime(2026, 9, 12, 11, 0),
      raceDate: DateTime(2026, 9, 13, 10, 0),
    );

    // Fin de semana 18-20 Sep 2026: NO HAY F1

    // GP 15: Azerbaiyán (Baku) - Próxima semana (Vie 25, Sáb 26, Dom 27)
    addGp(
      round: '15',
      raceName: 'Gran Premio de Azerbaiyán',
      circuit: 'Baku City Circuit',
      fpDate: DateTime(2026, 9, 25, 6, 30),
      qualyDate: DateTime(2026, 9, 26, 9, 0),
      raceDate: DateTime(2026, 9, 27, 8, 0),
    );

    // GP 16: Bahrein / Malasia (4 Oct 2026)
    addGp(
      round: '16',
      raceName: 'Gran Premio de Bahrein',
      circuit: 'Sepang Circuit',
      fpDate: DateTime(2026, 10, 2, 4, 30),
      qualyDate: DateTime(2026, 10, 3, 5, 0),
      raceDate: DateTime(2026, 10, 4, 4, 0),
    );

    // GP 17: Singapur (11 Oct 2026)
    addGp(
      round: '17',
      raceName: 'Gran Premio de Singapur',
      circuit: 'Marina Bay Street Circuit',
      fpDate: DateTime(2026, 10, 9, 6, 30),
      qualyDate: DateTime(2026, 10, 10, 10, 0),
      raceDate: DateTime(2026, 10, 11, 9, 0),
    );

    // GP 18: Estados Unidos (25 Oct 2026)
    addGp(
      round: '18',
      raceName: 'Gran Premio de Estados Unidos',
      circuit: 'Circuit of the Americas',
      fpDate: DateTime(2026, 10, 23, 14, 30),
      qualyDate: DateTime(2026, 10, 24, 19, 0),
      raceDate: DateTime(2026, 10, 25, 16, 0),
    );

    return events;
  }
}
