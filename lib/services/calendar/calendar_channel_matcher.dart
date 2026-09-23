import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';

/// Motor de correlación determinista entre eventos deportivos y canales instalados en MoAI TV.
class CalendarChannelMatcher {
  /// Retorna los canales del catálogo activo que coinciden con la transmisión del evento.
  ///
  /// Si no hay coincidencias o no hay plugins instalados, retorna una lista vacía.
  static List<Channel> findMatchingChannels(
    CalendarEvent event,
    List<Channel> channels, {
    int maxResults = 5,
  }) {
    if (channels.isEmpty) return const [];

    final Set<String> matchedIds = {};
    final List<Channel> results = [];

    final rawBroadcaster = event.broadcaster?.trim() ?? '';
    final subId = event.subscriptionId.toLowerCase();
    final competition = _normalize(event.competition);
    final title = _normalize(event.title);

    // 0. Coincidencias exactas por IDs explícitos informados por el evento (ej: moaiplug_daddylive)
    if (event.channelHints.isNotEmpty) {
      for (final hint in event.channelHints) {
        final trimmedHint = hint.trim();
        if (trimmedHint.isEmpty) continue;
        final normHint = _normalize(trimmedHint);

        for (final channel in channels) {
          if (matchedIds.contains(channel.id)) continue;

          final chPluginId = channel.pluginChannelId?.trim() ?? '';
          final chId = channel.id.trim();

          if (chPluginId == trimmedHint ||
              chId == trimmedHint ||
              _normalize(chPluginId) == normHint ||
              _normalize(chId) == normHint) {
            matchedIds.add(channel.id);
            results.add(channel);
            if (results.length >= maxResults) return results;
          }
        }
      }
    }

    // 1. Extraer tokens de búsqueda desde el broadcaster (ej: "TNT Sports / ESPN Premium" -> ["TNT Sports", "ESPN Premium"])
    final broadcasterTokens = _extractBroadcasterTokens(rawBroadcaster);

    // 2. Coincidencias primarias basadas en el broadcaster explícito
    for (final token in broadcasterTokens) {
      final normToken = _normalize(token);
      if (normToken.isEmpty) continue;

      for (final channel in channels) {
        if (matchedIds.contains(channel.id)) continue;

        final chName = _normalize(channel.name);
        final chId = _normalize(channel.pluginChannelId ?? channel.id);

        if (_isMatch(normToken, chName, chId)) {
          matchedIds.add(channel.id);
          results.add(channel);
          if (results.length >= maxResults) return results;
        }
      }
    }

    // 3. Coincidencias secundarias basadas en la suscripción y competición si aún hay espacio
    if (results.isEmpty) {
      final fallbackKeywords = _getFallbackKeywords(subId, competition, title);
      for (final kw in fallbackKeywords) {
        final normKw = _normalize(kw);
        for (final channel in channels) {
          if (matchedIds.contains(channel.id)) continue;

          // Solo buscar en canales deportivos si es un fallback genérico
          final chCat = channel.category.toLowerCase();
          final isSports = chCat.contains('deporte') || chCat.contains('sport');
          if (!isSports && !kw.contains('telefe') && !kw.contains('publica')) {
            continue;
          }

          final chName = _normalize(channel.name);
          final chId = _normalize(channel.pluginChannelId ?? channel.id);

          if (_isMatch(normKw, chName, chId)) {
            matchedIds.add(channel.id);
            results.add(channel);
            if (results.length >= maxResults) return results;
          }
        }
      }
    }

    return results;
  }

  static List<String> _extractBroadcasterTokens(String rawBroadcaster) {
    if (rawBroadcaster.isEmpty) return const [];

    // Separadores comunes: '/', '|', ';', ' o ', ' y ', ','
    final parts = rawBroadcaster
        .split(RegExp(r'[/|;,]|\b[oy]\b', caseSensitive: false))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty && p.length > 1)
        .toList();

    return parts.isNotEmpty ? parts : [rawBroadcaster];
  }

  static bool _isMatch(String target, String chName, String chId) {
    // Coincidencia exacta o contenida
    if (chName == target || chId == target) return true;

    // TNT Sports
    if (target.contains('tnt sport')) {
      if (chName.contains('tnt sport') || chId.contains('tnt_sport')) {
        return true;
      }
    }

    // ESPN Premium
    if (target.contains('espn premium')) {
      return chName.contains('espn premium') || chId.contains('espn_premium');
    }

    // ESPN genérico (coincide con ESPN, ESPN 2, etc.)
    if (target == 'espn' || target.startsWith('espn ')) {
      if (chName.startsWith('espn') || chId.startsWith('espn')) {
        return true;
      }
    }

    // TyC Sports
    if (target.contains('tyc')) {
      return chName.contains('tyc') || chId.contains('tyc');
    }

    // Fox Sports
    if (target.contains('fox sport')) {
      return chName.contains('fox sport') || chId.contains('fox_sport');
    }

    // DSports
    if (target.contains('dsport') || target.contains('directv')) {
      return chName.contains('dsport') || chId.contains('dsport');
    }

    // Telefe
    if (target.contains('telefe')) {
      return chName.contains('telefe') || chId.contains('telefe');
    }

    // TV Pública
    if (target.contains('publica')) {
      return chName.contains('publica') || chId.contains('publica');
    }

    // Coincidencia por palabra clave amplia
    return chName.contains(target) || chId.contains(target);
  }

  static List<String> _getFallbackKeywords(String subId, String comp, String title) {
    if (subId.contains('lpf') || comp.contains('liga profesional') || comp.contains('argentin')) {
      return const ['tnt sports premium', 'espn premium', 'tyc sports'];
    }
    if (subId.contains('f1') || comp.contains('formula 1') || comp.contains('f1')) {
      return const ['fox sports', 'espn', 'f1'];
    }
    if (subId.contains('champions') || comp.contains('champions')) {
      return const ['espn', 'fox sports'];
    }
    if (subId.contains('premier') || comp.contains('premier')) {
      return const ['espn'];
    }
    if (subId.contains('nba') || comp.contains('nba')) {
      return const ['nba', 'espn'];
    }
    if (subId.contains('motogp') || comp.contains('motogp')) {
      return const ['espn'];
    }
    return const [];
  }

  static String _normalize(String s) {
    var clean = s.toLowerCase();
    const withDia = 'áéíóúüñàèìòù';
    const withoutDia = 'aeiouunaeiou';
    for (var i = 0; i < withDia.length; i++) {
      clean = clean.replaceAll(withDia[i], withoutDia[i]);
    }
    return clean.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
