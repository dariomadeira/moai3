import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';

/// Decide qué eventos de la Agenda hay que avisar como "empezó" (o "empieza en
/// X minutos" con [leadMinutes]). Cada evento se avisa una sola vez.
class LiveEventDetector {
  /// Minutos de anticipación del aviso (0 = al empezar).
  int leadMinutes = 0;

  final Set<String> _notified = {};
  bool _primed = false;

  /// `true` si el evento no terminó y ya entró en la ventana de aviso.
  bool isInNotifyWindow(CalendarEvent event, {DateTime? nowUtc}) {
    if (event.status == CalendarEventStatus.finished) return false;
    final now = nowUtc ?? ArgentinaTime.utcNow();
    final notifyAt = event.startDateTime.toUtc().subtract(
      Duration(minutes: leadMinutes),
    );
    return !now.isBefore(notifyAt);
  }

  /// Primera carga: lo que ya está en curso o terminó no se avisa (la app
  /// recién arranca). Devuelve `false` si ya se había hecho.
  bool prime(Iterable<CalendarEvent> events) {
    if (_primed) return false;
    _primed = true;
    for (final ev in events) {
      if (isInNotifyWindow(ev) || ev.status == CalendarEventStatus.finished) {
        _notified.add(ev.id);
      }
    }
    return true;
  }

  /// Eventos que entraron en la ventana y todavía no se avisaron; quedan
  /// marcados como avisados.
  List<CalendarEvent> takeNew(Iterable<CalendarEvent> events) => [
    for (final e in events)
      if (!_notified.contains(e.id) && isInNotifyWindow(e) && _notified.add(e.id))
        e,
  ];
}
