import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/material.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/calendar/argentina_time.dart';

/// País con un desfase fijo respecto de UTC para la agenda.
class AgendaTimeZone {
  final String id;
  final String nameKey;
  final int offsetHours;

  const AgendaTimeZone({
    required this.id,
    required this.nameKey,
    required this.offsetHours,
  });
}

/// Zona horaria elegida para la agenda. Por defecto Argentina (UTC−3).
class AgendaClockProvider extends ChangeNotifier {
  static const String _zoneKey = 'agenda_time_zone_id';
  static const String _hoursKey = 'agenda_utc_offset_hours';
  static const String defaultZoneId = 'argentina';

  static const List<AgendaTimeZone> zones = [
    AgendaTimeZone(id: 'argentina', nameKey: LocaleKeys.tz_argentina, offsetHours: -3),
    AgendaTimeZone(id: 'uruguay', nameKey: LocaleKeys.tz_uruguay, offsetHours: -3),
    AgendaTimeZone(id: 'paraguay', nameKey: LocaleKeys.tz_paraguay, offsetHours: -3),
    AgendaTimeZone(id: 'brasil', nameKey: LocaleKeys.tz_brasil, offsetHours: -3),
    AgendaTimeZone(id: 'chile', nameKey: LocaleKeys.tz_chile, offsetHours: -4),
    AgendaTimeZone(id: 'bolivia', nameKey: LocaleKeys.tz_bolivia, offsetHours: -4),
    AgendaTimeZone(id: 'venezuela', nameKey: LocaleKeys.tz_venezuela, offsetHours: -4),
    AgendaTimeZone(id: 'peru', nameKey: LocaleKeys.tz_peru, offsetHours: -5),
    AgendaTimeZone(id: 'colombia', nameKey: LocaleKeys.tz_colombia, offsetHours: -5),
    AgendaTimeZone(id: 'ecuador', nameKey: LocaleKeys.tz_ecuador, offsetHours: -5),
    AgendaTimeZone(id: 'mexico', nameKey: LocaleKeys.tz_mexico, offsetHours: -6),
    AgendaTimeZone(id: 'usa_este', nameKey: LocaleKeys.tz_usa_este, offsetHours: -5),
    AgendaTimeZone(id: 'usa_centro', nameKey: LocaleKeys.tz_usa_centro, offsetHours: -6),
    AgendaTimeZone(id: 'usa_pacifico', nameKey: LocaleKeys.tz_usa_pacifico, offsetHours: -8),
    AgendaTimeZone(id: 'espana', nameKey: LocaleKeys.tz_espana, offsetHours: 1),
    AgendaTimeZone(id: 'reino_unido', nameKey: LocaleKeys.tz_reino_unido, offsetHours: 0),
    AgendaTimeZone(id: 'portugal', nameKey: LocaleKeys.tz_portugal, offsetHours: 0),
  ];

  final AppPreferences _prefs;
  late AgendaTimeZone _zone;

  AgendaClockProvider(this._prefs) {
    _zone = _restore();
    ArgentinaTime.offsetHours = _zone.offsetHours;
  }

  AgendaTimeZone get zone => _zone;

  int get offsetHours => _zone.offsetHours;

  String get formattedOffset => ArgentinaTime.formatOffset(_zone.offsetHours);

  Future<void> setZone(String id) async {
    AgendaTimeZone? next;
    for (final zone in zones) {
      if (zone.id == id) {
        next = zone;
        break;
      }
    }
    if (next == null || next.id == _zone.id) return;
    _zone = next;
    ArgentinaTime.offsetHours = next.offsetHours;
    await _prefs.saveString(_zoneKey, next.id);
    await _prefs.saveString(_hoursKey, '${next.offsetHours}');
    notifyListeners();
  }

  AgendaTimeZone _restore() {
    final savedId = _prefs.readOptionalString(_zoneKey);
    for (final zone in zones) {
      if (zone.id == savedId) return zone;
    }
    final parsed = int.tryParse(_prefs.readOptionalString(_hoursKey) ?? '');
    if (parsed != null) {
      for (final zone in zones) {
        if (zone.offsetHours == parsed) return zone;
      }
    }
    return zones.firstWhere((zone) => zone.id == defaultZoneId);
  }
}
