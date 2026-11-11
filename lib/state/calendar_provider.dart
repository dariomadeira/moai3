import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/data/repositories/calendar_repository.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/live_event_detector.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Proveedor de estado central para Suscripciones Deportivas y Calendario de Eventos en Moai TV.
class CalendarProvider extends ChangeNotifier {
  static const List<int> notifyLeadOptions = [0, 10, 15, 30];
  static const List<int> snackDurationOptions = [2, 4, 8];
  static const int defaultSnackDurationSeconds = 4;

  /// name/description guardan claves i18n; traducir en UI con `.tr()`.
  static const List<SportSubscription> defaultSubscriptions = [
    SportSubscription(
      id: 'f1',
      name: LocaleKeys.calendar_sub_f1_name,
      sport: 'motorsport',
      description: LocaleKeys.calendar_sub_f1_desc,
      icon: MoaiIcons.calendarSubF1,
    ),
    SportSubscription(
      id: 'lpf_ar',
      name: LocaleKeys.calendar_sub_lpf_name,
      sport: 'soccer',
      description: LocaleKeys.calendar_sub_lpf_desc,
      icon: MoaiIcons.calendarSubLpf,
    ),
    SportSubscription(
      id: 'champions',
      name: LocaleKeys.calendar_sub_champions_name,
      sport: 'soccer',
      description: LocaleKeys.calendar_sub_champions_desc,
      icon: MoaiIcons.calendarSubChampions,
    ),
    SportSubscription(
      id: 'premier',
      name: LocaleKeys.calendar_sub_premier_name,
      sport: 'soccer',
      description: LocaleKeys.calendar_sub_premier_desc,
      icon: MoaiIcons.calendarSubPremier,
    ),
    SportSubscription(
      id: 'nfl',
      name: LocaleKeys.calendar_sub_nfl_name,
      sport: 'american_football',
      description: LocaleKeys.calendar_sub_nfl_desc,
      icon: MoaiIcons.calendarSubNfl,
    ),
    SportSubscription(
      id: 'nba',
      name: LocaleKeys.calendar_sub_nba_name,
      sport: 'basketball',
      description: LocaleKeys.calendar_sub_nba_desc,
      icon: MoaiIcons.calendarSubNba,
    ),
  ];

  /// Retorna el ícono representativo de una suscripción o deporte para identificar el evento.
  static IconData getSubscriptionIcon(String subscriptionId) =>
      MoaiIcons.calendarSubIconFor(subscriptionId);

  /// REDISEÑO: un color por deporte para su ícono (se lee de un vistazo qué
  /// es cada evento).
  static const Map<String, Color> subscriptionColors = {
    'f1': Color(0xFFE10600), // rojo F1
    'lpf_ar': Color(0xFF2E8BC9), // celeste
    'champions': Color(0xFF1E3A8A), // azul noche
    'premier': Color(0xFF7B2CBF), // violeta
    'nfl': Color(0xFF15803D), // verde cancha
    'nba': Color(0xFFE8590C), // naranja pelota
  };

  /// Color del ícono de un deporte; sin uno propio, el acento.
  static Color getSubscriptionColor(String subscriptionId, Color fallback) =>
      subscriptionColors[subscriptionId] ?? fallback;

  List<SportSubscription> _subscriptions = [];
  List<CalendarEvent> _allEvents = [];
  List<CalendarEvent> get _events => _allEvents;
  set _events(List<CalendarEvent> value) {
    _allEvents = value;
    _clearEventCache();
  }

  /// Los eventos suscriptos, ya ordenados y agrupados por día de la zona de la
  /// Agenda: la grilla los pide varias veces por cada tecla.
  List<CalendarEvent>? _subscribedCache;
  Map<DateTime, List<CalendarEvent>>? _byDayCache;
  int _byDayOffsetHours = 0;

  void _clearEventCache() {
    _subscribedCache = null;
    _byDayCache = null;
  }

  List<CalendarEvent> _eventsOn(DateTime day) {
    var byDay = _byDayCache;
    if (byDay == null || _byDayOffsetHours != ArgentinaTime.offsetHours) {
      byDay = <DateTime, List<CalendarEvent>>{};
      for (final event in subscribedEvents) {
        byDay
            .putIfAbsent(ArgentinaTime.dateOnly(event.startDateTime), () => [])
            .add(event);
      }
      _byDayCache = byDay;
      _byDayOffsetHours = ArgentinaTime.offsetHours;
    }
    return byDay[day] ?? const [];
  }

  bool _isLoading = false;
  DateTime? _lastFetchTime;
  Timer? _statusTicker;
  int _lastKnownTodayCount = -1;
  int _lastKnownDay = -1;
  String _lastKnownTodayStatus = '';
  final _liveDetector = LiveEventDetector();
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

  final CalendarRepository _repository;

  CalendarProvider({AppPreferences? preferences, bool? startTicker})
    : _repository = CalendarRepository(preferences: preferences) {
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
    _lastKnownTodayStatus = todayStatusKey();

    // Cada minuto: si cambió el día, la cantidad de eventos de hoy o el
    // estado de alguno (empezó o terminó), avisa para que las pantallas
    // (p. ej. la tarjeta del Inicio) se actualicen solas.
    _statusTicker = Timer.periodic(const Duration(seconds: 60), (_) {
      final currentNow = ArgentinaTime.now();
      final currentCount = todayEventCount;
      final currentStatus = todayStatusKey();

      final dayChanged = currentNow.day != _lastKnownDay;
      final countChanged = currentCount != _lastKnownTodayCount;
      final statusChanged = currentStatus != _lastKnownTodayStatus;

      _checkNewLiveEvents();

      // Día nuevo: los eventos se bajan al arrancar; con el TV prendido días
      // hay que volver a pedirlos para enterarse de los nuevos.
      if (dayChanged) unawaited(refreshEvents(force: true));

      if (dayChanged || countChanged || statusChanged) {
        _lastKnownDay = currentNow.day;
        _lastKnownTodayCount = currentCount;
        _lastKnownTodayStatus = currentStatus;
        _notify();
      }
    });
  }

  /// Estado de los eventos de hoy (por empezar, en curso, terminado), en
  /// orden: cambia cuando alguno empieza o termina.
  @visibleForTesting
  String todayStatusKey() =>
      getEventsForDay(ArgentinaTime.now()).map((e) => e.status.index).join();

  /// Evalúa si hay eventos recién iniciados en las suscripciones activas y los emite agrupados.
  @visibleForTesting
  void checkNewLiveEvents() {
    _checkNewLiveEvents();
  }

  void _checkNewLiveEvents() {
    final newLive = _liveDetector.takeNew(subscribedEvents);
    if (newLive.isNotEmpty && !_disposed && !_liveEventsController.isClosed) {
      _liveEventsController.add(newLive);
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

  List<SportSubscription> get subscriptions =>
      List.unmodifiable(_subscriptions);
  bool get isLoading => _isLoading;

  /// Reemplaza los eventos sin pasar por la red (tests de widgets).
  @visibleForTesting
  void debugSetEvents(List<CalendarEvent> events) {
    _events = [...events]
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    // Evita que el refresh inicial del constructor pise estos eventos.
    _lastFetchTime = DateTime.now();
    // Ni que navegar de semana vaya a la red.
    _debugEventsFixed = true;
    _notify();
  }

  bool _debugEventsFixed = false;

  /// Retorna los eventos filtrados por las competiciones suscriptas y ordenados cronológicamente.
  List<CalendarEvent> get subscribedEvents {
    final cached = _subscribedCache;
    if (cached != null) return cached;
    final activeIds = _subscriptions
        .where((s) => s.isSubscribed)
        .map((s) => s.id)
        .toSet();

    final filtered = _events
        .where((e) => activeIds.contains(e.subscriptionId))
        .toList();

    filtered.sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return _subscribedCache = List.unmodifiable(filtered);
  }

  /// Contador de eventos de hoy para el Badge del NavigationRail (total programado para el día).
  int get todayEventCount {
    return _eventsOn(ArgentinaTime.dateOnly(ArgentinaTime.utcNow())).length;
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
    final events = [..._eventsOn(target)];
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
    final saved = await _repository.loadNotifyLeadMinutes();
    if (saved != null && notifyLeadOptions.contains(saved)) {
      _liveDetector.leadMinutes = saved;
    }
  }

  Future<void> _loadSnackDuration() async {
    final saved = await _repository.loadSnackDurationSeconds();
    if (saved != null && snackDurationOptions.contains(saved)) {
      _snackDurationSeconds = saved;
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      final savedActiveIds = await _repository.loadActiveSubscriptionIds();
      if (savedActiveIds == null) {
        _subscriptions = List.from(defaultSubscriptions);
      } else {
        final activeSet = savedActiveIds.toSet();
        _subscriptions = defaultSubscriptions.map((s) {
          return s.copyWith(isSubscribed: activeSet.contains(s.id));
        }).toList();
      }
      _clearEventCache();
      _notify();
    } catch (e) {
      _subscriptions = List.from(defaultSubscriptions);
      _clearEventCache();
    }
  }

  Future<void> toggleSubscription(String id) async {
    final index = _subscriptions.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final current = _subscriptions[index];
    final updated = current.copyWith(isSubscribed: !current.isSubscribed);
    _subscriptions[index] = updated;
    _clearEventCache();
    _notify();

    await _repository.saveActiveSubscriptionIds([
      for (final s in _subscriptions)
        if (s.isSubscribed) s.id,
    ]);

    // Sólo se bajan las ligas suscriptas: la recién activada llega ahora.
    if (updated.isSubscribed) {
      _failedWeeks.clear();
      unawaited(_loadCurrentMonths());
    }
  }

  /// Ligas suscriptas (las que bajan de ESPN; la F1 se baja siempre).
  List<String> get _activeLeagueIds => [
    for (final s in _subscriptions)
      if (s.isSubscribed && SportsScheduleService.leagues.containsKey(s.id))
        s.id,
  ];

  /// Baja lo que falte de los meses alrededor de hoy para las ligas
  /// suscriptas. Una liga activada mientras tanto se suma; lo que falla no se
  /// repite acá.
  Future<void> _loadCurrentMonths() async {
    if (_disposed || _debugEventsFixed || _isLoading || _loadingLeagues) return;
    final tried = <String>{};
    _loadingLeagues = true;
    try {
      while (!_disposed && !_isLoading) {
        final missing = [
          for (final key in SportsScheduleService.loadKeys(
            _activeLeagueIds,
            SportsScheduleService.monthsToFetch(ArgentinaTime.now()),
          ))
            if (!_loadedLeagueMonths.contains(key) && tried.add(key)) key,
        ];
        if (missing.isEmpty) break;
        _notify();
        final result = await _repository.fetchLeagues(missing);
        if (_disposed || _isLoading) return;
        _mergeLeagueEvents(result);
        _notify();
      }
    } catch (e) {
      debugPrint('[CalendarProvider] Error al bajar ligas: $e');
    } finally {
      _loadingLeagues = false;
      _notify();
    }
  }

  /// Suma partidos a los que ya hay. Lo que ya estaba en curso no se avisa.
  void _mergeLeagueEvents(
    ({List<CalendarEvent> events, Set<String> loaded}) result,
  ) {
    final known = {for (final e in _events) e.id};
    _events = [
      ..._events,
      for (final e in result.events)
        if (!known.contains(e.id)) e,
    ]..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    _loadedLeagueMonths.addAll(result.loaded);
    _liveDetector.markStarted(result.events);
  }

  Future<void> refreshEvents({bool force = false}) async {
    // Si se consultó hace menos de 5 minutos y no es forzado, no saturar la red
    if (!force &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 5 &&
        _events.isNotEmpty) {
      return;
    }
    // Ya hay una carga (p. ej. la de medianoche y el botón a la vez).
    if (_isLoading) return;

    _isLoading = true;
    _notify();

    final requested = _activeLeagueIds;
    try {
      final result = await _repository.fetchEvents(
        ArgentinaTime.now(),
        requested,
      );
      _events = result.events;
      // Lo de semanas lejanas se vuelve a pedir al ir a verlas.
      _loadedLeagueMonths
        ..clear()
        ..addAll(result.loaded);
      // Recargar da otra oportunidad a las semanas que fallaron.
      _failedWeeks.clear();
      _lastFetchTime = DateTime.now();
      // La primera carga no avisa lo que ya estaba en curso al abrir la app.
      if (!_liveDetector.prime(_events)) _checkNewLiveEvents();
    } catch (e) {
      debugPrint('[CalendarProvider] Error al actualizar eventos: $e');
    } finally {
      _isLoading = false;
      _notify();
    }
    // Se activó una liga durante la carga: no estaba en el pedido.
    if (!requested.toSet().containsAll(_activeLeagueIds)) {
      unawaited(_loadCurrentMonths());
    }
  }

  /// Ligas y meses ya bajados ([SportsScheduleService.loadKeys]). La F1 trae
  /// la temporada entera; los demás, sólo los meses alrededor de hoy y los de
  /// las semanas que se fueron a ver.
  final Set<String> _loadedLeagueMonths = {};
  bool _loadingLeagues = false;
  final Set<DateTime> _loadingWeeks = {};

  /// Semanas que no se pudieron bajar: no se reintentan solas (sin red, el
  /// panel las pediría en cada redibujo) hasta [refreshEvents].
  final Set<DateTime> _failedWeeks = {};

  static DateTime _weekKey(DateTime monday) =>
      DateTime(monday.year, monday.month, monday.day);

  /// Si la semana del lunes [monday] ya tiene sus partidos.
  bool isWeekLoaded(DateTime monday) =>
      _debugEventsFixed || _missingForWeek(monday).isEmpty;

  /// Lo que falta bajar de las ligas suscriptas para esa semana.
  List<String> _missingForWeek(DateTime monday) => [
    for (final key in SportsScheduleService.loadKeys(
      _activeLeagueIds,
      SportsScheduleService.monthsForWeek(monday),
    ))
      if (!_loadedLeagueMonths.contains(key)) key,
  ];

  /// Si hay que bajar la semana del lunes [monday]: falta, no se está
  /// pidiendo y no falló antes.
  bool needsWeekLoad(DateTime monday) {
    final key = _weekKey(monday);
    return !_isLoading &&
        !_loadingLeagues &&
        !isWeekLoaded(key) &&
        !_loadingWeeks.contains(key) &&
        !_failedWeeks.contains(key);
  }

  /// Baja los partidos de la semana del lunes [monday] si faltan (al
  /// navegar a semanas lejanas en la Agenda). No hace nada si ya están o
  /// si ya se están pidiendo, ni durante la carga completa.
  Future<void> ensureWeekLoaded(DateTime monday) async {
    final key = _weekKey(monday);
    if (!needsWeekLoad(key)) return;
    _loadingWeeks.add(key);
    _notify();
    try {
      final result = await _repository.fetchLeagues(_missingForWeek(key));
      if (_disposed) return;
      _mergeLeagueEvents(result);
      if (!isWeekLoaded(key)) _failedWeeks.add(key);
    } catch (e) {
      debugPrint('[CalendarProvider] Error al bajar la semana $key: $e');
      _failedWeeks.add(key);
    } finally {
      _loadingWeeks.remove(key);
      _notify();
    }
  }

  /// Se está bajando alguna semana lejana.
  bool get isLoadingWeek => _loadingWeeks.isNotEmpty || _loadingLeagues;

  int get notifyLeadMinutes => _liveDetector.leadMinutes;

  int get snackDurationSeconds => _snackDurationSeconds;

  Duration get liveSnackDuration => Duration(seconds: _snackDurationSeconds);

  Future<void> setSnackDurationSeconds(int seconds) async {
    final next = snackDurationOptions.contains(seconds)
        ? seconds
        : defaultSnackDurationSeconds;
    if (next == _snackDurationSeconds) return;
    _snackDurationSeconds = next;
    await _repository.saveSnackDurationSeconds(next);
    _notify();
  }

  Future<void> setNotifyLeadMinutes(int minutes) async {
    final next = notifyLeadOptions.contains(minutes) ? minutes : 0;
    if (next == _liveDetector.leadMinutes) return;
    _liveDetector.leadMinutes = next;
    await _repository.saveNotifyLeadMinutes(next);
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
      return LocaleKeys.calendar_live_notification_soon.tr(
        namedArgs: {'minutes': '$leadMinutes', 'title': events.first.title},
      );
    }
    if (events.length == 1) {
      return LocaleKeys.calendar_live_notification_single.tr(
        namedArgs: {'title': events.first.title},
      );
    }

    final count = events.length;
    final t1 = _shortMatchTitle(events[0]);
    final t2 = _shortMatchTitle(events[1]);

    if (count == 2) {
      return LocaleKeys.calendar_live_notification_two.tr(
        namedArgs: {'t1': t1, 't2': t2},
      );
    } else {
      return LocaleKeys.calendar_live_notification_multiple.tr(
        namedArgs: {
          'count': '$count',
          't1': t1,
          't2': t2,
          'more': '${count - 2}',
        },
      );
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
    if (events.isEmpty) return MoaiIcons.calendarLive;
    if (events.length == 1) {
      return getSubscriptionIcon(events.first.subscriptionId);
    }
    final firstSub = events.first.subscriptionId;
    if (events.every((e) => e.subscriptionId == firstSub)) {
      return getSubscriptionIcon(firstSub);
    }
    return MoaiIcons.calendarLive;
  }
}
