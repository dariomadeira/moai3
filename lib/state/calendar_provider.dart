import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/services/calendar/f1_calendar_service.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';

/// Proveedor de estado central para Suscripciones Deportivas y Calendario de Eventos en Moai TV.
class CalendarProvider extends ChangeNotifier {
  static const String _prefsKey = 'moai_calendar_subscriptions';

  static final List<SportSubscription> defaultSubscriptions = [
    const SportSubscription(
      id: 'f1',
      name: 'Fórmula 1',
      sport: 'motorsport',
      description: 'Prácticas, clasificación y carreras en vivo.',
      icon: Icons.sports_motorsports_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'lpf_ar',
      name: 'Fútbol Argentino (LPF)',
      sport: 'soccer',
      description: 'Torneo y Copa de la Liga Profesional.',
      icon: Icons.sports_soccer_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'champions',
      name: 'Champions League',
      sport: 'soccer',
      description: 'Encuentros de la UEFA Champions League.',
      icon: Icons.emoji_events_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'premier',
      name: 'Premier League',
      sport: 'soccer',
      description: 'Partidos de la Premier League inglesa.',
      icon: Icons.sports_soccer_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'nfl',
      name: 'NFL (Fútbol Americano)',
      sport: 'american_football',
      description: 'Temporada regular, playoffs y Super Bowl.',
      icon: Icons.sports_football_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'motogp',
      name: 'MotoGP',
      sport: 'motorsport',
      description: 'Mundial de motociclismo y carrera Sprint.',
      icon: Icons.two_wheeler_outlined,
      isSubscribed: false,
    ),
    const SportSubscription(
      id: 'nba',
      name: 'NBA (Básquet)',
      sport: 'basketball',
      description: 'Temporada regular y playoffs de la NBA.',
      icon: Icons.sports_basketball_outlined,
      isSubscribed: false,
    ),
  ];

  /// Retorna el ícono representativo de una suscripción o deporte para identificar el evento.
  static IconData getSubscriptionIcon(String subscriptionId) {
    for (final s in defaultSubscriptions) {
      if (s.id == subscriptionId) {
        return s.icon;
      }
    }
    final lower = subscriptionId.toLowerCase();
    if (lower.contains('f1')) return Icons.sports_motorsports_outlined;
    if (lower.contains('motogp')) return Icons.two_wheeler_outlined;
    if (lower.contains('nfl') || lower.contains('football')) return Icons.sports_football_outlined;
    if (lower.contains('nba') || lower.contains('basket')) return Icons.sports_basketball_outlined;
    if (lower.contains('champions')) return Icons.emoji_events_outlined;
    if (lower.contains('premier') || lower.contains('lpf') || lower.contains('soccer')) {
      return Icons.sports_soccer_outlined;
    }
    return Icons.sports_outlined;
  }

  List<SportSubscription> _subscriptions = [];
  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  Timer? _statusTicker;
  int _lastKnownTodayCount = -1;
  int _lastKnownDay = -1;
  final Set<String> _notifiedEventIds = {};
  bool _isFirstEventsLoad = true;
  final StreamController<List<CalendarEvent>> _liveEventsController =
      StreamController<List<CalendarEvent>>.broadcast();

  /// Stream que emite los nuevos eventos en vivo que comenzaron (1 evento o múltiples agrupados).
  Stream<List<CalendarEvent>> get onLiveEventsStarted =>
      _liveEventsController.stream;

  /// Permite deshabilitar el ticker en tests unitarios o widgets para evitar timers pendientes.
  static bool enablePeriodicTicker = true;

  CalendarProvider({bool? startTicker}) {
    _init();
    final shouldStart = startTicker ?? (enablePeriodicTicker && !_isInTest);
    if (shouldStart) {
      _startTicker();
    }
  }

  static bool get _isInTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  void _startTicker() {
    _statusTicker?.cancel();
    final now = DateTime.now();
    _lastKnownDay = now.day;
    _lastKnownTodayCount = todayEventCount;

    _statusTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      final currentNow = DateTime.now();
      final currentCount = todayEventCount;

      final dayChanged = currentNow.day != _lastKnownDay;
      final countChanged = currentCount != _lastKnownTodayCount;

      _checkNewLiveEvents();

      if (dayChanged || countChanged) {
        _lastKnownDay = currentNow.day;
        _lastKnownTodayCount = currentCount;
        notifyListeners();
      }
    });
  }

  /// Evalúa si hay eventos recién iniciados en las suscripciones activas y los emite agrupados.
  void checkNewLiveEvents() {
    _checkNewLiveEvents();
  }

  void _checkNewLiveEvents() {
    final newLive = subscribedEvents
        .where((e) =>
            e.status == CalendarEventStatus.live &&
            !_notifiedEventIds.contains(e.id))
        .toList();

    if (newLive.isNotEmpty) {
      for (final e in newLive) {
        _notifiedEventIds.add(e.id);
      }
      _liveEventsController.add(newLive);
    }
  }

  @override
  void dispose() {
    _statusTicker?.cancel();
    _statusTicker = null;
    _liveEventsController.close();
    super.dispose();
  }

  List<SportSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  List<CalendarEvent> get allEvents => List.unmodifiable(_events);
  bool get isLoading => _isLoading;

  /// Retorna los eventos filtrados por las competiciones suscriptas y ordenados cronológicamente.
  List<CalendarEvent> get subscribedEvents {
    final activeIds = _subscriptions
        .where((s) => s.isSubscribed)
        .map((s) => s.id)
        .toSet();

    final filtered = _events
        .where((e) => activeIds.contains(e.subscriptionId))
        .toList();

    filtered.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return filtered;
  }

  /// Contador de eventos de hoy para el Badge del NavigationRail (total programado para el día).
  int get todayEventCount {
    return subscribedEvents.where((e) => e.isToday).length;
  }

  /// Agrupa los eventos suscriptos por día (solo año-mes-día).
  Map<DateTime, List<CalendarEvent>> get eventsGroupedByDay {
    final Map<DateTime, List<CalendarEvent>> map = {};
    for (final ev in subscribedEvents) {
      final day = DateTime(ev.startDateTime.year, ev.startDateTime.month, ev.startDateTime.day);
      map.putIfAbsent(day, () => []).add(ev);
    }
    return map;
  }

  /// Obtiene el lunes correspondiente a una fecha (a las 00:00:00).
  static DateTime getMondayOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  /// Retorna los 7 días de la semana (Lunes a Domingo) para un determinado offset de semana (-1, 0, +1...).
  static List<DateTime> getDaysForWeekOffset(int offset, [DateTime? baseDate]) {
    final now = baseDate ?? DateTime.now();
    final currentMonday = getMondayOfWeek(now);
    final targetMonday = currentMonday.add(Duration(days: offset * 7));
    return List.generate(7, (i) => targetMonday.add(Duration(days: i)));
  }

  /// Retorna los eventos de las suscripciones activas para un día específico,
  /// ordenados con prioridad inteligente: LIVE primero, UPCOMING segundo, FINISHED al fondo.
  List<CalendarEvent> getEventsForDay(DateTime day) {
    final events = subscribedEvents.where((e) {
      return e.startDateTime.year == day.year &&
          e.startDateTime.month == day.month &&
          e.startDateTime.day == day.day;
    }).toList();
    events.sort(CalendarEvent.compareByStatusAndDate);
    return events;
  }

  Future<void> _init() async {
    await _loadSubscriptions();
    await refreshEvents();
  }

  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedActiveIds = prefs.getStringList(_prefsKey);

      if (savedActiveIds == null) {
        _subscriptions = List.from(defaultSubscriptions);
      } else {
        final activeSet = savedActiveIds.toSet();
        _subscriptions = defaultSubscriptions.map((s) {
          return s.copyWith(isSubscribed: activeSet.contains(s.id));
        }).toList();
      }
      notifyListeners();
    } catch (e) {
      _subscriptions = List.from(defaultSubscriptions);
    }
  }

  Future<void> toggleSubscription(String id) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final current = _subscriptions[index];
    final updated = current.copyWith(isSubscribed: !current.isSubscribed);
    _subscriptions[index] = updated;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIds = _subscriptions
          .where((s) => s.isSubscribed)
          .map((s) => s.id)
          .toList();
      await prefs.setStringList(_prefsKey, activeIds);
    } catch (e) {
      debugPrint('[CalendarProvider] Error guardando suscripciones: $e');
    }
  }

  Future<void> refreshEvents({bool force = false}) async {
    // Si se consultó hace menos de 5 minutos y no es forzado, no saturar la red
    if (!force && _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 5 &&
        _events.isNotEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final f1EventsFuture = F1CalendarService.fetchF1Events();
      final sportsEventsFuture = SportsScheduleService.fetchSportsEvents();

      final results = await Future.wait([f1EventsFuture, sportsEventsFuture]);
      final f1 = results[0];
      final sports = results[1];

      // Generar calendario de soporte para semanas -1 hasta +4
      final now = DateTime.now();
      final currentMonday = getMondayOfWeek(now);
      final List<CalendarEvent> generated = [];
      for (var offset = -1; offset <= 4; offset++) {
        final mon = currentMonday.add(Duration(days: offset * 7));
        generated.addAll(generateMockFixturesForWeek(mon));
      }

      // Si tenemos eventos deportivos reales para el día de hoy, omitimos los mock fixtures
      // de hoy para que la columna del día actual solo muestre partidos reales.
      final todayRealEvents = sports.where((e) => e.isToday).isNotEmpty;
      final filteredGenerated = generated.where((e) {
        if (todayRealEvents && e.isToday) {
          return false;
        }
        return true;
      });

      final combined = <CalendarEvent>[];
      final seenIds = <String>{};

      for (final ev in [...f1, ...sports, ...filteredGenerated]) {
        if (seenIds.add(ev.id)) {
          combined.add(ev);
        }
      }

      combined.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

      _events = combined;
      _lastFetchTime = DateTime.now();

      if (_isFirstEventsLoad) {
        _isFirstEventsLoad = false;
        for (final ev in combined) {
          if (ev.status == CalendarEventStatus.live ||
              ev.status == CalendarEventStatus.finished) {
            _notifiedEventIds.add(ev.id);
          }
        }
      } else {
        _checkNewLiveEvents();
      }
    } catch (e) {
      debugPrint('[CalendarProvider] Error al actualizar eventos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Formatea el mensaje agrupado para notificaciones de eventos en vivo.
  static String formatLiveEventsMessage(List<CalendarEvent> events) {
    if (events.isEmpty) return '';
    if (events.length == 1) {
      const key = 'calendar_live_notification_single';
      final res = tr(key, namedArgs: {'title': events.first.title});
      if (res != key) return res;
      return 'Comenzó en vivo: ${events.first.title}';
    }

    final count = events.length;
    final t1 = _shortMatchTitle(events[0]);
    final t2 = _shortMatchTitle(events[1]);

    if (count == 2) {
      const key = 'calendar_live_notification_two';
      final res = tr(key, namedArgs: {'t1': t1, 't2': t2});
      if (res != key) return res;
      return 'Comenzaron 2 eventos: $t1 y $t2';
    } else {
      const key = 'calendar_live_notification_multiple';
      final res = tr(key, namedArgs: {
        'count': '$count',
        't1': t1,
        't2': t2,
        'more': '${count - 2}',
      });
      if (res != key) return res;
      return 'Comenzaron $count eventos en vivo: $t1, $t2 y ${count - 2} más';
    }
  }

  static String _shortMatchTitle(CalendarEvent ev) {
    final t = ev.title;
    if (t.length <= 22) return t;
    final parts = t.split(RegExp(r'\s+vs\.?\s+|\s*-\s*', caseSensitive: false));
    if (parts.length >= 2) {
      final t1 = parts[0].trim();
      final t2 = parts[1].trim();
      if ('$t1 vs $t2'.length <= 24) return '$t1 vs $t2';
      return t1;
    }
    return '${t.substring(0, 20)}...';
  }

  /// Obtiene el ícono representativo para la notificación en vivo.
  static IconData getLiveEventsIcon(List<CalendarEvent> events) {
    if (events.isEmpty) return Icons.live_tv_rounded;
    if (events.length == 1) {
      return getSubscriptionIcon(events.first.subscriptionId);
    }
    final firstSub = events.first.subscriptionId;
    if (events.every((e) => e.subscriptionId == firstSub)) {
      return getSubscriptionIcon(firstSub);
    }
    return Icons.live_tv_rounded;
  }

  /// Genera eventos representativos para una semana (del Lunes al Domingo dado).
  static List<CalendarEvent> generateMockFixturesForWeek(DateTime monday) {
    final cleanMonday = DateTime(monday.year, monday.month, monday.day);
    final List<CalendarEvent> fixtures = [];

    // Lunes
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_mon_${cleanMonday.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'Estudiantes vs Gimnasia LP',
      competition: 'Liga Profesional',
      startDateTime: cleanMonday.add(const Duration(hours: 20)),
      sessionType: 'Fecha Regular',
      broadcaster: 'TNT Sports',
    ));

    // Martes
    final tue = cleanMonday.add(const Duration(days: 1));
    fixtures.add(CalendarEvent(
      id: 'mock_ucl_tue_1_${tue.millisecondsSinceEpoch}',
      subscriptionId: 'champions',
      title: 'Real Madrid vs Bayern Múnich',
      competition: 'UEFA Champions League',
      startDateTime: tue.add(const Duration(hours: 16)),
      sessionType: 'Fase de Grupos',
      broadcaster: 'ESPN / Disney+',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_ucl_tue_2_${tue.millisecondsSinceEpoch}',
      subscriptionId: 'champions',
      title: 'PSG vs Juventus',
      competition: 'UEFA Champions League',
      startDateTime: tue.add(const Duration(hours: 16)),
      sessionType: 'Fase de Grupos',
      broadcaster: 'Fox Sports',
    ));

    // Miércoles
    final wed = cleanMonday.add(const Duration(days: 2));
    fixtures.add(CalendarEvent(
      id: 'mock_ucl_wed_1_${wed.millisecondsSinceEpoch}',
      subscriptionId: 'champions',
      title: 'Barcelona vs Inter de Milán',
      competition: 'UEFA Champions League',
      startDateTime: wed.add(const Duration(hours: 16)),
      sessionType: 'Fase de Grupos',
      broadcaster: 'ESPN / Disney+',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_nba_wed_${wed.millisecondsSinceEpoch}',
      subscriptionId: 'nba',
      title: 'Golden State Warriors vs Miami Heat',
      competition: 'NBA',
      startDateTime: wed.add(const Duration(hours: 21, minutes: 30)),
      sessionType: 'Temporada Regular',
      broadcaster: 'ESPN 2',
    ));

    // Jueves
    final thu = cleanMonday.add(const Duration(days: 3));
    fixtures.add(CalendarEvent(
      id: 'mock_nfl_thu_${thu.millisecondsSinceEpoch}',
      subscriptionId: 'nfl',
      title: 'Kansas City Chiefs vs Baltimore Ravens',
      competition: 'NFL · Thursday Night',
      startDateTime: thu.add(const Duration(hours: 21, minutes: 15)),
      sessionType: 'Temporada Regular',
      broadcaster: 'ESPN',
    ));

    // Viernes
    final fri = cleanMonday.add(const Duration(days: 4));
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_fri_1_${fri.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'Racing Club vs Lanús',
      competition: 'Liga Profesional',
      startDateTime: fri.add(const Duration(hours: 19, minutes: 0)),
      sessionType: 'Fecha Regular',
      broadcaster: 'ESPN Premium',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_fri_2_${fri.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'Newell\'s vs Rosario Central',
      competition: 'Liga Profesional',
      startDateTime: fri.add(const Duration(hours: 21, minutes: 15)),
      sessionType: 'Clásico',
      broadcaster: 'TNT Sports',
    ));

    // Sábado
    final sat = cleanMonday.add(const Duration(days: 5));
    fixtures.add(CalendarEvent(
      id: 'mock_pl_sat_1_${sat.millisecondsSinceEpoch}',
      subscriptionId: 'premier',
      title: 'Liverpool vs Chelsea',
      competition: 'Premier League',
      startDateTime: sat.add(const Duration(hours: 8, minutes: 30)),
      sessionType: 'Matchday',
      broadcaster: 'ESPN',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_pl_sat_2_${sat.millisecondsSinceEpoch}',
      subscriptionId: 'premier',
      title: 'Manchester City vs Arsenal',
      competition: 'Premier League',
      startDateTime: sat.add(const Duration(hours: 13, minutes: 30)),
      sessionType: 'Matchday',
      broadcaster: 'ESPN / Disney+',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_sat_1_${sat.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'San Lorenzo vs Huracán',
      competition: 'Liga Profesional',
      startDateTime: sat.add(const Duration(hours: 17, minutes: 0)),
      sessionType: 'Clásico',
      broadcaster: 'TNT Sports',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_sat_2_${sat.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'Boca Juniors vs Vélez Sarsfield',
      competition: 'Liga Profesional',
      startDateTime: sat.add(const Duration(hours: 19, minutes: 30)),
      sessionType: 'Fecha Regular',
      broadcaster: 'ESPN Premium',
    ));

    // Domingo
    final sun = cleanMonday.add(const Duration(days: 6));
    fixtures.add(CalendarEvent(
      id: 'mock_pl_sun_1_${sun.millisecondsSinceEpoch}',
      subscriptionId: 'premier',
      title: 'Tottenham vs Manchester United',
      competition: 'Premier League',
      startDateTime: sun.add(const Duration(hours: 11, minutes: 30)),
      sessionType: 'Super Sunday',
      broadcaster: 'ESPN',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_lpf_sun_super_${sun.millisecondsSinceEpoch}',
      subscriptionId: 'lpf_ar',
      title: 'River Plate vs Independiente',
      competition: 'Liga Profesional',
      startDateTime: sun.add(const Duration(hours: 17, minutes: 30)),
      sessionType: 'Clásico',
      broadcaster: 'ESPN Premium / TNT Sports',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_nba_sun_${sun.millisecondsSinceEpoch}',
      subscriptionId: 'nba',
      title: 'Los Angeles Lakers vs Boston Celtics',
      competition: 'NBA · Sunday Game',
      startDateTime: sun.add(const Duration(hours: 20, minutes: 0)),
      sessionType: 'Temporada Regular',
      broadcaster: 'ESPN',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_nfl_sun_snf_${sun.millisecondsSinceEpoch}',
      subscriptionId: 'nfl',
      title: 'San Francisco 49ers vs Dallas Cowboys',
      competition: 'NFL · Sunday Night Football',
      startDateTime: sun.add(const Duration(hours: 21, minutes: 20)),
      sessionType: 'SNF',
      broadcaster: 'ESPN / Disney+',
    ));
    fixtures.add(CalendarEvent(
      id: 'mock_nfl_sun_afternoon_${sun.millisecondsSinceEpoch}',
      subscriptionId: 'nfl',
      title: 'Green Bay Packers vs Chicago Bears',
      competition: 'NFL · Sunday Afternoon',
      startDateTime: sun.add(const Duration(hours: 14, minutes: 0)),
      sessionType: 'Fecha Regular',
      broadcaster: 'Fox Sports',
    ));

    return fixtures;
  }
}
