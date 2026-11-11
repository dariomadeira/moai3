import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/calendar_event.dart';

/// Partidos de las ligas de la Agenda (todas menos la F1, que tiene su
/// servicio) desde la API pública de ESPN.
///
/// Se pide el mes entero de cada liga en una sola consulta (pedir un rango
/// de días no devuelve nada). Al arrancar, los meses que cubren la semana
/// pasada, la actual y la próxima ([monthsToFetch]); al ir a una semana más
/// lejana, los de esa semana ([monthsForWeek]). Un mes de NBA son ~3 MB de
/// JSON, así que se procesa en otro isolate.
class SportsScheduleService {
  static const String apiBase = 'https://site.api.espn.com/apis/site/v2/sports';

  /// Id de suscripción → liga en ESPN.
  static const Map<String, String> leagues = {
    'lpf_ar': 'soccer/arg.1',
    'premier': 'soccer/eng.1',
    'champions': 'soccer/uefa.champions',
    'nfl': 'football/nfl',
    'nba': 'basketball/nba',
  };

  /// Descargas a la vez: el TV procesa cada una en un hilo aparte.
  static const int _maxConcurrent = 3;

  /// Las descargas (liga y mes) de [subscriptionIds] en [months]. Lo que no
  /// es una liga de ESPN (la F1) se ignora.
  static List<String> loadKeys(
    Iterable<String> subscriptionIds,
    Iterable<String> months,
  ) => [
    for (final id in subscriptionIds)
      if (leagues.containsKey(id))
        for (final month in months) '$id|$month',
  ];

  /// Los partidos de [keys] ([loadKeys]). [loaded] son las que bajaron bien:
  /// una que falló no se da por cargada y se vuelve a pedir sólo ella.
  static Future<({List<CalendarEvent> events, Set<String> loaded})> fetchKeys(
    Iterable<String> keys,
  ) async {
    final wanted = keys.toSet().toList();
    if (wanted.isEmpty) return (events: <CalendarEvent>[], loaded: <String>{});
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final loaded = <String>{};
      final seenIds = <String>{};
      final events = <CalendarEvent>[];
      for (var i = 0; i < wanted.length; i += _maxConcurrent) {
        final batch = wanted.skip(i).take(_maxConcurrent).toList();
        final results = await Future.wait(
          batch.map((key) {
            final [id, month] = key.split('|');
            return _fetchMonth(client, id, leagues[id]!, month);
          }),
        );
        for (var j = 0; j < batch.length; j++) {
          final result = results[j];
          if (result == null) continue;
          loaded.add(batch[j]);
          events.addAll(result.where((ev) => seenIds.add(ev.id)));
        }
      }
      return (events: events, loaded: loaded);
    } finally {
      client.close();
    }
  }

  /// Meses (`yyyyMM`) que cubren desde el lunes de la semana pasada hasta el
  /// domingo de la próxima, contados desde [today] (fecha de Argentina).
  static List<String> monthsToFetch(DateTime today) {
    final monday = _mondayOf(today);
    return _monthsBetween(
      monday.subtract(const Duration(days: 7)),
      monday.add(const Duration(days: 13)),
    );
  }

  /// Meses (`yyyyMM`) de la semana que empieza el lunes [monday], con un día
  /// de margen a cada lado: ESPN agrupa por la fecha de EE. UU. y un partido
  /// de la noche del último día puede caer en el mes siguiente.
  static List<String> monthsForWeek(DateTime monday) {
    final start = _mondayOf(monday);
    return _monthsBetween(
      start.subtract(const Duration(days: 1)),
      start.add(const Duration(days: 7)),
    );
  }

  static DateTime _mondayOf(DateTime day) => DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - 1));

  static List<String> _monthsBetween(DateTime from, DateTime to) {
    final months = <String>[];
    var cursor = DateTime(from.year, from.month);
    while (!cursor.isAfter(DateTime(to.year, to.month))) {
      months.add('${cursor.year}${cursor.month.toString().padLeft(2, '0')}');
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  /// null si no se pudo bajar (red, HTTP o JSON roto).
  static Future<List<CalendarEvent>?> _fetchMonth(
    HttpClient client,
    String subscriptionId,
    String league,
    String month,
  ) async {
    final uri = Uri.parse(
      '$apiBase/$league/scoreboard?dates=$month&limit=1000',
    );
    try {
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        debugPrint(
          '[SportsScheduleService] $league $month: HTTP ${response.statusCode}',
        );
        return null;
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 20));
      return await compute(_parseInIsolate, (subscriptionId, body));
    } catch (e) {
      debugPrint('[SportsScheduleService] $league $month: $e');
      return null;
    }
  }

  static List<CalendarEvent> _parseInIsolate((String, String) args) {
    final data = json.decode(args.$2) as Map<String, dynamic>;
    return parseScoreboard(args.$1, data);
  }

  /// Arma los eventos de una respuesta `scoreboard` de ESPN. Los partidos
  /// sin hora confirmada (`timeValid: false`: ESPN pone una hora de relleno)
  /// quedan en su día con la hora "a confirmar"; los postergados o
  /// suspendidos, afuera.
  static List<CalendarEvent> parseScoreboard(
    String subscriptionId,
    Map<String, dynamic> data,
  ) {
    final events = <CalendarEvent>[];
    for (final raw in data['events'] as List<dynamic>? ?? const []) {
      if (raw is! Map<String, dynamic>) continue;
      final competitions = raw['competitions'] as List<dynamic>? ?? const [];
      final competition = competitions.isNotEmpty
          ? competitions.first as Map<String, dynamic>?
          : null;
      final start = DateTime.tryParse(
        (competition?['date'] ?? raw['date'])?.toString() ?? '',
      );
      if (start == null) continue;

      final statusType =
          (raw['status'] as Map<String, dynamic>?)?['type']
              as Map<String, dynamic>?;
      final statusName = statusType?['name']?.toString() ?? '';
      if (_skippedStatuses.any(statusName.contains)) continue;

      final title = _title(competition) ?? raw['name']?.toString() ?? '';
      if (title.isEmpty) continue;

      events.add(
        CalendarEvent(
          id: 'espn_${subscriptionId}_${raw['id']}',
          subscriptionId: subscriptionId,
          title: title,
          competition: _competitionName(subscriptionId),
          startDateTime: start.toUtc(),
          status: switch (statusType?['state']) {
            'in' => CalendarEventStatus.live,
            'post' => CalendarEventStatus.finished,
            _ => null,
          },
          sessionType: LocaleKeys.calendar_session_match,
          broadcaster: _broadcaster(subscriptionId),
          timeConfirmed: competition?['timeValid'] != false,
        ),
      );
    }
    return events;
  }

  static const _skippedStatuses = [
    'POSTPONED',
    'CANCELED',
    'CANCELLED',
    'SUSPENDED',
    'ABANDONED',
  ];

  /// "Local vs Visitante".
  static String? _title(Map<String, dynamic>? competition) {
    final competitors =
        competition?['competitors'] as List<dynamic>? ?? const [];
    String? team(String side) {
      for (final c in competitors) {
        if (c is Map && c['homeAway'] == side) {
          final t = c['team'] as Map?;
          return (t?['displayName'] ?? t?['shortDisplayName'])?.toString();
        }
      }
      return null;
    }

    final home = team('home');
    final away = team('away');
    if (home == null || away == null) return null;
    return '$home vs $away';
  }

  static String _competitionName(String subscriptionId) {
    switch (subscriptionId) {
      case 'lpf_ar':
        return 'Liga Profesional Argentina';
      case 'premier':
        return 'Premier League';
      case 'champions':
        return 'Champions League';
      case 'nfl':
        return 'NFL';
      case 'nba':
        return 'NBA';
      default:
        return subscriptionId;
    }
  }

  /// Quién lo pasa en Argentina (ESPN informa los canales de EE. UU.). Con
  /// esto [CalendarChannelMatcher] busca el canal entre los instalados.
  static String _broadcaster(String subscriptionId) {
    switch (subscriptionId) {
      case 'lpf_ar':
        return 'TNT Sports / ESPN Premium';
      case 'premier':
      case 'champions':
        return 'ESPN / Disney+';
      case 'nfl':
        return 'ESPN';
      case 'nba':
        return 'ESPN / NBA TV';
      default:
        return 'TV';
    }
  }
}
