import 'package:moai3/services/calendar/argentina_time.dart';

enum CalendarEventStatus {
  upcoming,
  live,
  finished,
}

/// Representa un evento o partido programado en el calendario deportivo.
class CalendarEvent {
  final String id;
  final String subscriptionId;
  final String title;
  final String competition;
  final DateTime startDateTime;
  final CalendarEventStatus? _explicitStatus;
  final String? sessionType;
  final String? broadcaster;
  final List<String> channelHints;

  const CalendarEvent({
    required this.id,
    required this.subscriptionId,
    required this.title,
    required this.competition,
    required this.startDateTime,
    CalendarEventStatus? status,
    this.sessionType,
    this.broadcaster,
    this.channelHints = const [],
  }) : _explicitStatus = status;

  /// Retorna la duración estimada del evento según el deporte y tipo de sesión.
  Duration get estimatedDuration {
    final sub = subscriptionId.toLowerCase();
    final session = (sessionType ?? '').toLowerCase();
    final tit = title.toLowerCase();

    // 1. Motorsport: F1 y MotoGP
    if (sub.contains('f1') || sub.contains('motogp')) {
      if (session.contains('práctica') ||
          session.contains('practice') ||
          session.contains('libre') ||
          session.contains('fp') ||
          tit.contains('práctica') ||
          tit.contains('practice')) {
        return const Duration(minutes: 75); // 60 min de sesión + margen
      }
      if (session.contains('qualy') ||
          session.contains('clasificación') ||
          session.contains('qualifying') ||
          tit.contains('clasificación') ||
          tit.contains('qualy')) {
        return const Duration(minutes: 75); // Q1+Q2+Q3 ~60 min + margen
      }
      if (session.contains('sprint') || tit.contains('sprint')) {
        return const Duration(minutes: 60); // Sprint dura ~30 min + margen
      }
      // Carrera principal: F1/MotoGP duran ~90-110 min (máx FIA 120 min)
      return const Duration(minutes: 130);
    }

    // 2. NFL / Fútbol Americano
    if (sub.contains('nfl') || sub.contains('football') || sub.contains('american')) {
      // Un partido de NFL dura típicamente entre 3h y 3h30 (reloj parado, pausas)
      return const Duration(minutes: 210);
    }

    // 3. NBA / Básquetbol
    if (sub.contains('nba') || sub.contains('basket')) {
      // 4 cuartos de 12 min + entretiempo + tiempos muertos ~2h15
      return const Duration(minutes: 140);
    }

    // 4. Fútbol (LPF, Champions League, Premier League, etc.)
    if (sub.contains('lpf') ||
        sub.contains('premier') ||
        sub.contains('champions') ||
        sub.contains('soccer') ||
        sub.contains('liga')) {
      // 90 min reglamentarios + 15 min entretiempo + adición / demoras
      return const Duration(minutes: 115);
    }

    // 5. Por defecto para otros deportes
    return const Duration(minutes: 120);
  }

  /// Retorna el estado real y dinámico del evento en base al tiempo actual y su fecha de inicio.
  CalendarEventStatus get status {
    if (_explicitStatus == CalendarEventStatus.finished) {
      return CalendarEventStatus.finished;
    }
    final now = ArgentinaTime.utcNow();
    final start = startDateTime.toUtc();
    if (now.isBefore(start)) {
      return _explicitStatus ?? CalendarEventStatus.upcoming;
    }
    final diff = now.difference(start);
    if (diff <= estimatedDuration) {
      return CalendarEventStatus.live;
    }
    return CalendarEventStatus.finished;
  }

  /// Indica si el evento ocurre durante el día de hoy en Argentina.
  bool get isToday {
    return ArgentinaTime.dateOnly(startDateTime) ==
        ArgentinaTime.dateOnly(ArgentinaTime.utcNow());
  }

  /// Retorna la fecha formateada dd/MM/yyyy en hora de Argentina.
  String get formattedDate {
    final civil = ArgentinaTime.toCivil(startDateTime);
    final day = civil.day.toString().padLeft(2, '0');
    final month = civil.month.toString().padLeft(2, '0');
    return '$day/$month/${civil.year}';
  }

  /// Retorna la hora formateada HH:mm en hora de Argentina.
  String get formattedTime {
    final civil = ArgentinaTime.toCivil(startDateTime);
    final hour = civil.hour.toString().padLeft(2, '0');
    final minute = civil.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Prioridad numérica de ordenamiento para interfaz de TV:
  /// 0 = live (máxima prioridad, arriba de todo)
  /// 1 = upcoming (segunda prioridad, eventos por venir)
  /// 2 = finished (tercera prioridad, eventos pasados al fondo)
  int get statusPriority {
    switch (status) {
      case CalendarEventStatus.live:
        return 0;
      case CalendarEventStatus.upcoming:
        return 1;
      case CalendarEventStatus.finished:
        return 2;
    }
  }

  /// Comparador determinista: primero por estado (LIVE -> UPCOMING -> FINISHED)
  /// y como criterio secundario por fecha y hora de inicio ascendente.
  static int compareByStatusAndDate(CalendarEvent a, CalendarEvent b) {
    final statusComp = a.statusPriority.compareTo(b.statusPriority);
    if (statusComp != 0) return statusComp;
    return a.startDateTime.compareTo(b.startDateTime);
  }

  CalendarEvent copyWith({
    String? id,
    String? subscriptionId,
    String? title,
    String? competition,
    DateTime? startDateTime,
    CalendarEventStatus? status,
    String? sessionType,
    String? broadcaster,
    List<String>? channelHints,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      title: title ?? this.title,
      competition: competition ?? this.competition,
      startDateTime: startDateTime ?? this.startDateTime,
      status: status ?? _explicitStatus,
      sessionType: sessionType ?? this.sessionType,
      broadcaster: broadcaster ?? this.broadcaster,
      channelHints: channelHints ?? this.channelHints,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEvent &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
