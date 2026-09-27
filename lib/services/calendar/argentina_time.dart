/// Hora civil de la agenda. El desfase por defecto es Argentina (UTC−3).
///
/// Los eventos se guardan como instante UTC. El día de la grilla, “hoy” y la
/// hora que se muestra salen de estos campos, no del huso del equipo.
class ArgentinaTime {
  /// Horas respecto de UTC. Lo actualiza [AgendaClockProvider].
  static int offsetHours = -3;

  static Duration get offset => Duration(hours: offsetHours);

  static String formatOffset(int hours) {
    if (hours == 0) return 'UTC';
    final sign = hours > 0 ? '+' : '-';
    return 'UTC$sign${hours.abs()}';
  }

  /// Reloj UTC inyectable en tests. En la app queda en null.
  static DateTime Function()? debugUtcNow;

  static DateTime utcNow() => debugUtcNow?.call() ?? DateTime.now().toUtc();

  /// Hora de pared en Argentina. Los campos year/month/day/hour son ART.
  static DateTime now() => toCivil(utcNow());

  static DateTime toCivil(DateTime instant) {
    final shifted = instant.toUtc().add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static DateTime dateOnly(DateTime instant) {
    final civil = toCivil(instant);
    return DateTime(civil.year, civil.month, civil.day);
  }

  /// Interpreta año, mes, día y hora como hora de Argentina y devuelve el UTC.
  static DateTime fromCivil(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    return DateTime.utc(year, month, day, hour, minute, second).subtract(offset);
  }
}
