import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/f1_calendar_service.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Proveedor de estado central para Suscripciones Deportivas y Calendario de Eventos en Moai TV.
class CalendarProvider extends ChangeNotifier {
  static const String _prefsKey = 'moai_calendar_subscriptions';
  static const String _notifyLeadKey = 'moai_calendar_notify_lead_minutes';
  static const String _snackDurationKey = 'moai_calendar_snack_duration_seconds';
  static const List<int> notifyLeadOptions = [0, 10, 15, 30];
  static const List<int> snackDurationOptions = [2, 4, 8];
  static const int defaultSnackDurationSeconds = 4;

  /// name/description guardan claves i18n; traducir en UI con `.tr()`.
  static const List<SportSubscription> defaultSubscriptions = [
    SportSubscription(
      id: 'f1',
      name: 'calendar_sub_f1_name',
      sport: 'motorsport',
      description: 'calendar_sub_f1_desc',
      icon: MoaiIcons.calendarSubF1,
    ),
    SportSubscription(
      id: 'lpf_ar',
      name: 'calendar_sub_lpf_name',
      sport: 'soccer',
      description: 'calendar_sub_lpf_desc',
      icon: MoaiIcons.calendarSubLpf,
    ),
    SportSubscription(
      id: 'champions',
      name: 'calendar_sub_champions_name',
      sport: 'soccer',
      description: 'calendar_sub_champions_desc',
      icon: MoaiIcons.calendarSubChampions,
    ),
    SportSubscription(
      id: 'premier',
      name: 'calendar_sub_premier_name',
      sport: 'soccer',
      description: 'calendar_sub_premier_desc',
      icon: MoaiIcons.calendarSubPremier,
    ),
    SportSubscription(
      id: 'nfl',
      name: 'calendar_sub_nfl_name',
      sport: 'american_football',
      description: 'calendar_sub_nfl_desc',
      icon: MoaiIcons.calendarSubNfl,
    ),
    SportSubscription(
      id: 'motogp',
      name: 'calendar_sub_motogp_name',
      sport: 'motorsport',
      description: 'calendar_sub_motogp_desc',
      icon: MoaiIcons.calendarSubMotogp,
    ),
    SportSubscription(
      id: 'nba',
      name: 'calendar_sub_nba_name',
      sport: 'basketball',
      description: 'calendar_sub_nba_desc',
      icon: MoaiIcons.calendarSubNba,
    ),
  ];

  /// Retorna el ícono representativo de una suscripción o deporte para identificar el evento.
  static IconData getSubscriptionIcon(String subscriptionId) =>
      MoaiIcons.calendarSubIconFor(subscriptionId);

  List<SportSubscription> _subscriptions = [];
  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  DateTime? _lastFetchTime;
  Timer? _statusTicker;
  int _lastKnownTodayCount = -1;
  int _lastKnownDay = -1;
  final Set<String> _notifiedEventIds = {};
  bool _isFirstEventsLoad = true;
  int _notifyLeadMinutes = 0;
  int _snackDurationSeconds = defaultSnackDurationSeconds;
  final StreamController<List<CalendarEvent>> _liveEventsController =
      StreamController<List<CalendarEvent>>.broadcast();
  bool _disposed = false;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Stream que emite los nuevos eventos en vivo que comenzaron (1 evento o múltiples agrupados).
  Stream<List<CalendarEvent>> get onLiveEventsStarted =>
      _liveEventsController.stream;

  /// Permite deshabilitar el ticker en tests unitarios o widgets para evitar timers pendientes.
  static bool enablePeriodicTicker = true;

  AppPreferences? _preferences;

  Future<AppPreferences> _prefs() async =>
      _preferences ??= await AppPreferences.init();

  CalendarProvider({this._preferences, bool? startTicker}) {
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
    final now = ArgentinaTime.now();
    _lastKnownDay = now.day;
    _lastKnownTodayCount = todayEventCount;

    _statusTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      final currentNow = ArgentinaTime.now();
      final currentCount = todayEventCount;

      final dayChanged = currentNow.day != _lastKnownDay;
      final countChanged = currentCount != _lastKnownTodayCount;

      _checkNewLiveEvents();

      if (dayChanged || countChanged) {
        _lastKnownDay = currentNow.day;
        _lastKnownTodayCount = currentCount;
        _notify();
      }
    });
  }

  /// Evalúa si hay eventos recién iniciados en las suscripciones activas y los emite agrupados.
  @visibleForTesting
  void checkNewLiveEvents() {
    _checkNewLiveEvents();
  }

  bool _isInNotifyWindow(CalendarEvent event) {
    if (event.status == CalendarEventStatus.finished) return false;
    final now = ArgentinaTime.utcNow();
    final start = event.startDateTime.toUtc();
    final notifyAt = start.subtract(Duration(minutes: _notifyLeadMinutes));
    return !now.isBefore(notifyAt);
  }

  void _checkNewLiveEvents() {
    final newLive = subscribedEvents
        .where((e) =>
            _isInNotifyWindow(e) && !_notifiedEventIds.contains(e.id))
        .toList();

    if (newLive.isNotEmpty) {
      for (final e in newLive) {
        _notifiedEventIds.add(e.id);
      }
      if (!_disposed && !_liveEventsController.isClosed) {
        _liveEventsController.add(newLive);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statusTicker?.cancel();
    _statusTicker = null;
    if (!_liveEventsController.isClosed) {
      _liveEventsController.close();
    }
    super.dispose();
  }

  List<SportSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;

  /// Reemplaza los eventos sin pasar por la red (tests de widgets).
  @visibleForTesting
  void debugSetEvents(List<CalendarEvent> events) {
    _events = [...events]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    // Evita que el refresh inicial del constructor pise estos eventos.
    _lastFetchTime = DateTime.now();
    _notify();
  }

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

  /// Obtiene el lunes correspondiente a una fecha (a las 00:00:00).
  static DateTime getMondayOfWeek(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  /// Retorna los 7 días de la semana (Lunes a Domingo) para un determinado offset de semana (-1, 0, +1...).
  static List<DateTime> getDaysForWeekOffset(int offset, [DateTime? baseDate]) {
    final now = baseDate ?? ArgentinaTime.now();
    final currentMonday = getMondayOfWeek(now);
    final targetMonday = currentMonday.add(Duration(days: offset * 7));
    return List.generate(7, (i) => targetMonday.add(Duration(days: i)));
  }

  /// Retorna los eventos de las suscripciones activas para un día específico,
  /// ordenados con prioridad inteligente: LIVE primero, UPCOMING segundo, FINISHED al fondo.
  List<CalendarEvent> getEventsForDay(DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    final events = subscribedEvents.where((e) {
      return ArgentinaTime.dateOnly(e.startDateTime) == target;
    }).toList();
    events.sort(CalendarEvent.compareByStatusAndDate);
    return events;
  }

  Future<void> _init() async {
    await _loadSubscriptions();
    await _loadNotifyLead();
    await _loadSnackDuration();
    await refreshEvents();
  }

  Future<void> _loadNotifyLead() async {
    try {
      final prefs = await _prefs();
      final saved = prefs.readOptionalInt(_notifyLeadKey);
      if (saved != null && notifyLeadOptions.contains(saved)) {
        _notifyLeadMinutes = saved;
      }
    } catch (e) {
      debugPrint('[CalendarProvider] Error al leer aviso: $e');
    }
  }

  Future<void> _loadSnackDuration() async {
    try {
      final prefs = await _prefs();
      final saved = prefs.readOptionalInt(_snackDurationKey);
      if (saved != null && snackDurationOptions.contains(saved)) {
        _snackDurationSeconds = saved;
      }
    } catch (e) {
      debugPrint('[CalendarProvider] Error al leer duración del snack: $e');
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      final prefs = await _prefs();
      final savedActiveIds = prefs.readOptionalStringList(_prefsKey);

      if (savedActiveIds == null) {
        _subscriptions = List.from(defaultSubscriptions);
      } else {
        final activeSet = savedActiveIds.toSet();
        _subscriptions = defaultSubscriptions.map((s) {
          return s.copyWith(isSubscribed: activeSet.contains(s.id));
        }).toList();
      }
      _notify();
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
    _notify();

    try {
      final prefs = await _prefs();
      final activeIds = _subscriptions
          .where((s) => s.isSubscribed)
          .map((s) => s.id)
          .toList();
      await prefs.saveStringList(_prefsKey, activeIds);
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
    _notify();

    try {
      final f1EventsFuture = F1CalendarService.fetchF1Events();
      final sportsEventsFuture = SportsScheduleService.fetchSportsEvents();

      final results = await Future.wait([f1EventsFuture, sportsEventsFuture]);
      final f1 = results[0];
      final sports = results[1];

      final combined = <CalendarEvent>[];
      final seenIds = <String>{};

      for (final ev in [...f1, ...sports]) {
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
          if (_isInNotifyWindow(ev) ||
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
      _notify();
    }
  }

  int get notifyLeadMinutes => _notifyLeadMinutes;

  int get snackDurationSeconds => _snackDurationSeconds;

  Duration get liveSnackDuration => Duration(seconds: _snackDurationSeconds);

  Future<void> setSnackDurationSeconds(int seconds) async {
    final next = snackDurationOptions.contains(seconds)
        ? seconds
        : defaultSnackDurationSeconds;
    if (next == _snackDurationSeconds) return;
    _snackDurationSeconds = next;
    try {
      final prefs = await _prefs();
      await prefs.saveInt(_snackDurationKey, next);
    } catch (e) {
      debugPrint('[CalendarProvider] Error al guardar duración del snack: $e');
    }
    _notify();
  }

  Future<void> setNotifyLeadMinutes(int minutes) async {
    final next = notifyLeadOptions.contains(minutes) ? minutes : 0;
    if (next == _notifyLeadMinutes) return;
    _notifyLeadMinutes = next;
    try {
      final prefs = await _prefs();
      await prefs.saveInt(_notifyLeadKey, next);
    } catch (e) {
      debugPrint('[CalendarProvider] Error al guardar aviso: $e');
    }
    _notify();
  }

  static String formatLiveEventsMessage(
    List<CalendarEvent> events, {
    int leadMinutes = 0,
  }) {
    if (events.isEmpty) return '';
    if (events.length == 1 &&
        leadMinutes > 0 &&
        events.first.status == CalendarEventStatus.upcoming) {
      const key = 'calendar_live_notification_soon';
      final res = tr(key, namedArgs: {
        'minutes': '$leadMinutes',
        'title': events.first.title,
      });
      if (res != key) return res;
      return 'En $leadMinutes min: ${events.first.title}';
    }
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
    if (events.isEmpty) return MoaiIcons.liveTvOutlined;
    if (events.length == 1) {
      return getSubscriptionIcon(events.first.subscriptionId);
    }
    final firstSub = events.first.subscriptionId;
    if (events.every((e) => e.subscriptionId == firstSub)) {
      return getSubscriptionIcon(firstSub);
    }
    return MoaiIcons.liveTvOutlined;
  }
}
