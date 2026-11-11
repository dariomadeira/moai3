import 'package:flutter/foundation.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/calendar/f1_calendar_service.dart';
import 'package:moai3/services/calendar/sports_schedule_service.dart';

/// Datos de la Agenda: eventos de las fuentes deportivas y preferencias
/// guardadas (suscripciones, anticipación del aviso, duración del snack).
class CalendarRepository {
  CalendarRepository({this._preferences});

  static const String _subscriptionsKey = 'moai_calendar_subscriptions';
  static const String _notifyLeadKey = 'moai_calendar_notify_lead_minutes';
  static const String _snackDurationKey =
      'moai_calendar_snack_duration_seconds';

  AppPreferences? _preferences;

  Future<AppPreferences> _prefs() async =>
      _preferences ??= await AppPreferences.init();

  /// F1 (la temporada entera) y, de las ligas [leagueIds], los meses alrededor
  /// de [today], sin duplicados y en orden cronológico. [loaded] son las
  /// descargas de ligas que salieron bien
  /// ([SportsScheduleService.loadKeys]).
  Future<({List<CalendarEvent> events, Set<String> loaded})> fetchEvents(
    DateTime today,
    Iterable<String> leagueIds,
  ) async {
    final f1 = F1CalendarService.fetchF1Events();
    final sports = fetchLeagues(
      SportsScheduleService.loadKeys(
        leagueIds,
        SportsScheduleService.monthsToFetch(today),
      ),
    );
    final sportsResult = await sports;
    final seenIds = <String>{};
    final events = [
      for (final ev in [...await f1, ...sportsResult.events])
        if (seenIds.add(ev.id)) ev,
    ]..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    return (events: events, loaded: sportsResult.loaded);
  }

  /// Sólo los partidos de las descargas [keys].
  Future<({List<CalendarEvent> events, Set<String> loaded})> fetchLeagues(
    Iterable<String> keys,
  ) => SportsScheduleService.fetchKeys(keys);

  /// Ids de suscripciones activas, o `null` si nunca se guardaron.
  Future<List<String>?> loadActiveSubscriptionIds() async =>
      (await _prefs()).readOptionalStringList(_subscriptionsKey);

  Future<void> saveActiveSubscriptionIds(List<String> ids) =>
      _save((p) => p.saveStringList(_subscriptionsKey, ids), 'suscripciones');

  Future<int?> loadNotifyLeadMinutes() => _readInt(_notifyLeadKey, 'aviso');

  Future<void> saveNotifyLeadMinutes(int minutes) =>
      _save((p) => p.saveInt(_notifyLeadKey, minutes), 'aviso');

  Future<int?> loadSnackDurationSeconds() =>
      _readInt(_snackDurationKey, 'duración del snack');

  Future<void> saveSnackDurationSeconds(int seconds) =>
      _save((p) => p.saveInt(_snackDurationKey, seconds), 'duración del snack');

  Future<int?> _readInt(String key, String what) async {
    try {
      return (await _prefs()).readOptionalInt(key);
    } catch (e) {
      debugPrint('[CalendarRepository] Error al leer $what: $e');
      return null;
    }
  }

  Future<void> _save(
    Future<void> Function(AppPreferences p) write,
    String what,
  ) async {
    try {
      await write(await _prefs());
    } catch (e) {
      debugPrint('[CalendarRepository] Error al guardar $what: $e');
    }
  }
}
