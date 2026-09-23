import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/calendar_event.dart';

/// Servicio para consultar eventos y partidos deportivos de las principales ligas.
class SportsScheduleService {
  static const String eventsApiEndpoint = 'https://daddylive.li/api/events';

  static Future<List<CalendarEvent>> fetchSportsEvents() async {
    final List<CalendarEvent> events = [];

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(eventsApiEndpoint));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = json.decode(body) as Map<String, dynamic>;
        final categories = data['categories'] as Map<String, dynamic>? ?? {};
        events.addAll(parseCategories(categories));
      }
    } catch (e) {
      debugPrint('[SportsScheduleService] Error al consultar eventos en vivo: $e');
    }

    return events;
  }

  /// Parsea y deduplica los eventos deportivos agrupados por categoría.
  static List<CalendarEvent> parseCategories(Map<String, dynamic> categories, [DateTime? baseUtc]) {
    final List<CalendarEvent> events = [];
    final seenMatchKeys = <String>{};

    for (final entry in categories.entries) {
      final catName = entry.key;
      final catEvents = entry.value as List<dynamic>? ?? [];

      final subId = _mapCategoryToSubscriptionId(catName);
      if (subId == null) continue;

      for (var i = 0; i < catEvents.length; i++) {
        final ev = catEvents[i] as Map<String, dynamic>?;
        if (ev == null) continue;

        final rawTitle = ev['event'] as String? ?? '';
        final rawTime = ev['time'] as String? ?? '';
        if (rawTitle.isEmpty) continue;

        final dt = _parseEventDateTime(rawTime, baseUtc);
        final cleanTitle = _cleanTitle(rawTitle);
        final teamKey = _normalizeTeamKey(cleanTitle);

        // Deduplicación por deporte, equipos normalizados y ventana horaria
        final dedupKey = '${subId}_${teamKey}_${dt.year}_${dt.month}_${dt.day}_${(dt.hour / 2).floor()}';
        if (!seenMatchKeys.add(dedupKey)) {
          continue;
        }

        final isExplicitLive = rawTime.toLowerCase() == 'live';
        final rawChannels = ev['channels'] as List<dynamic>? ?? const [];
        final channelHints = _extractChannelHints(rawChannels);

        events.add(CalendarEvent(
          id: 'ev_${subId}_${teamKey.hashCode}_${dt.millisecondsSinceEpoch}',
          subscriptionId: subId,
          title: cleanTitle,
          competition: _cleanCompetitionName(catName, subId),
          startDateTime: dt,
          status: isExplicitLive ? CalendarEventStatus.live : null,
          sessionType: 'Partido',
          broadcaster: _suggestBroadcaster(subId, rawTitle),
          channelHints: channelHints,
        ));
      }
    }

    return events;
  }

  static List<String> _extractChannelHints(List<dynamic> rawChannels) {
    if (rawChannels.isEmpty) return const [];
    final hints = <String>{};

    for (final ch in rawChannels) {
      if (ch is! Map) continue;
      final url = ch['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        final idParam = uri?.queryParameters['id'];
        if (idParam != null && idParam.trim().isNotEmpty) {
          hints.add(idParam.trim());
        }
      }
      final directId = ch['id']?.toString() ?? ch['channel_id']?.toString();
      if (directId != null && directId.trim().isNotEmpty) {
        hints.add(directId.trim());
      }
    }

    return hints.toList();
  }

  static String? _mapCategoryToSubscriptionId(String catName) {
    final lower = catName.toLowerCase();
    if (lower.contains('lpf') || lower.contains('argentin') || lower.contains('primera division')) {
      return 'lpf_ar';
    }
    if (lower.contains('premier league')) {
      return 'premier';
    }
    if (lower.contains('champions') || lower.contains('uefa')) {
      return 'champions';
    }
    if (lower.contains('nfl') || lower.contains('am. football')) {
      return 'nfl';
    }
    if (lower.contains('motogp') || lower.contains('moto gp')) {
      return 'motogp';
    }
    if (lower.contains('nba') || lower.contains('basketball')) {
      return 'nba';
    }
    return null;
  }

  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F000}-\u{1FAFF}'
    r'\u{2600}-\u{27BF}'
    r'\u{FE00}-\u{FE0F}'
    r'\u{200D}]',
    unicode: true,
  );

  static String _stripEmojis(String text) {
    return text.replaceAll(_emojiRegex, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _cleanCompetitionName(String catName, String subId) {
    switch (subId) {
      case 'lpf_ar':
        return 'Liga Profesional Argentina';
      case 'premier':
        return 'Premier League';
      case 'champions':
        return 'Champions League';
      case 'nfl':
        return 'NFL';
      case 'motogp':
        return 'MotoGP';
      case 'nba':
        return 'NBA';
      default:
        return _stripEmojis(catName.replaceAll(RegExp(r'[^\w\s]'), '')).trim();
    }
  }

  static String _cleanTitle(String raw) {
    // Quitar prefijos como '⚽ England - Premier League : ' y sanitizar emojis por completo
    var s = raw;
    final colonIndex = s.indexOf(':');
    if (colonIndex != -1 && colonIndex < s.length - 1) {
      s = s.substring(colonIndex + 1).trim();
    }
    return _stripEmojis(s);
  }

  static String _suggestBroadcaster(String subId, String title) {
    switch (subId) {
      case 'lpf_ar':
        return 'TNT Sports / ESPN Premium';
      case 'premier':
      case 'champions':
        return 'ESPN / Disney+';
      case 'nfl':
        return 'ESPN';
      case 'nba':
        return 'ESPN / NBA TV';
      case 'motogp':
        return 'ESPN';
      default:
        return 'TV';
    }
  }

  static String _normalizeTeamKey(String title) {
    final clean = title
        .replaceAll(RegExp(r'[\(\)🇺🇸🇨🇦]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    List<String> teams = [];
    if (clean.contains(' vs. ')) {
      teams = clean.split(' vs. ');
    } else if (clean.contains(' vs ')) {
      teams = clean.split(' vs ');
    } else if (clean.contains(' - ')) {
      teams = clean.split(' - ');
    } else if (clean.contains(' x ')) {
      teams = clean.split(' x ');
    }

    if (teams.length == 2) {
      final t1 = teams[0]
          .replaceAll(RegExp(r'\bw\b'), '')
          .replaceAll(RegExp(r'\bwnba\b'), '')
          .replaceAll(RegExp(r'\bnfl\b'), '')
          .replaceAll(RegExp(r'\bnba\b'), '')
          .trim();
      final t2 = teams[1]
          .replaceAll(RegExp(r'\bw\b'), '')
          .replaceAll(RegExp(r'\bwnba\b'), '')
          .replaceAll(RegExp(r'\bnfl\b'), '')
          .replaceAll(RegExp(r'\bnba\b'), '')
          .trim();
      final sorted = [t1, t2]..sort();
      return sorted.join('_vs_');
    }
    return clean;
  }

  static DateTime _parseEventDateTime(String timeStr, [DateTime? baseUtc]) {
    final nowLocal = DateTime.now();
    if (timeStr.toLowerCase() == 'live') {
      return nowLocal;
    }
    // Formato común "HH:mm" (hora provista en UTC por el feed)
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;

      final nowUtc = baseUtc ?? DateTime.now().toUtc();
      var eventDateUtc = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, h, m);

      // Si la hora del feed difiere sustancialmente de la hora UTC actual,
      // ajustamos el día (+1 o -1 en UTC) dentro de la ventana de 24 horas del feed:
      if (nowUtc.hour - h >= 14) {
        eventDateUtc = eventDateUtc.add(const Duration(days: 1));
      } else if (h - nowUtc.hour >= 14) {
        eventDateUtc = eventDateUtc.subtract(const Duration(days: 1));
      }
      return eventDateUtc.toLocal();
    }
    return nowLocal;
  }
}
