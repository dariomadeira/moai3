import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/calendar/calendar_channel_matcher.dart';

void main() {
  group('CalendarChannelMatcher', () {
    final tntSports = Channel(
      id: 'ar_tnt_sports',
      name: 'TNT Sports',
      logoUrl: 'https://example.com/tnt.png',
      fallbackUrls: const [],
      category: 'Deportes',
      country: 'Argentina',
      pluginId: 'moaiplug_ar',
      pluginChannelId: 'tnt_sports_ar',
      pluginTag: 'AR',
    );

    final espnPremium = Channel(
      id: 'ar_espn_premium',
      name: 'ESPN Premium',
      logoUrl: 'https://example.com/espn_prem.png',
      fallbackUrls: const [],
      category: 'Deportes',
      country: 'Argentina',
      pluginId: 'moaiplug_ar',
      pluginChannelId: 'espn_premium_ar',
      pluginTag: 'AR',
    );

    final foxSports = Channel(
      id: 'ar_fox_sports',
      name: 'Fox Sports',
      logoUrl: 'https://example.com/fox.png',
      fallbackUrls: const [],
      category: 'Deportes',
      country: 'Argentina',
      pluginId: 'moaiplug_ar',
      pluginChannelId: 'fox_sports_ar',
      pluginTag: 'AR',
    );

    final cnnNews = Channel(
      id: 'cnn_es',
      name: 'CNN en Español',
      logoUrl: 'https://example.com/cnn.png',
      fallbackUrls: const [],
      category: 'Noticias',
      country: 'EEUU',
    );

    final allChannels = [tntSports, espnPremium, foxSports, cnnNews];

    test('returns empty list when no channels are available', () {
      final event = CalendarEvent(
        id: 'ev_1',
        subscriptionId: 'lpf_ar',
        title: 'Boca Juniors vs River Plate',
        competition: 'Liga Profesional',
        startDateTime: DateTime.now(),
        broadcaster: 'TNT Sports',
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(event, []);
      expect(matches, isEmpty);
    });

    test('matches direct multiple broadcasters separated by slash', () {
      final event = CalendarEvent(
        id: 'ev_superclasico',
        subscriptionId: 'lpf_ar',
        title: 'Boca Juniors vs River Plate',
        competition: 'Liga Profesional',
        startDateTime: DateTime.now(),
        broadcaster: 'TNT Sports / ESPN Premium',
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(event, allChannels);
      expect(matches.length, 2);
      expect(matches.map((c) => c.name), containsAll(['TNT Sports', 'ESPN Premium']));
    });

    test('matches single broadcaster case-insensitively and ignores unrelated channels', () {
      final event = CalendarEvent(
        id: 'ev_f1',
        subscriptionId: 'f1',
        title: 'Gran Premio de Mónaco - Carrera',
        competition: 'Fórmula 1',
        startDateTime: DateTime.now(),
        broadcaster: 'FOX SPORTS',
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(event, allChannels);
      expect(matches.length, 1);
      expect(matches.first.id, 'ar_fox_sports');
    });

    test('falls back to sports channels based on competition/subscription when broadcaster is empty', () {
      final event = CalendarEvent(
        id: 'ev_lpf_no_broadcaster',
        subscriptionId: 'lpf_ar',
        title: 'Racing vs Independiente',
        competition: 'Liga Profesional Argentina',
        startDateTime: DateTime.now(),
        broadcaster: null,
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(event, allChannels);
      expect(matches.isNotEmpty, isTrue);
      final names = matches.map((c) => c.name).toList();
      expect(names.contains('TNT Sports') || names.contains('ESPN Premium'), isTrue);
      // Non-sports channels should never be matched by sports fallback
      expect(names.contains('CNN en Español'), isFalse);
    });

    test('respects maxResults parameter limit', () {
      final event = CalendarEvent(
        id: 'ev_multi',
        subscriptionId: 'lpf_ar',
        title: 'Partido de Prueba',
        competition: 'Liga Profesional',
        startDateTime: DateTime.now(),
        broadcaster: 'TNT Sports / ESPN Premium / Fox Sports',
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(
        event,
        allChannels,
        maxResults: 1,
      );
      expect(matches.length, 1);
    });

    test('returns empty list when no broadcaster and no fallback keywords match', () {
      final event = CalendarEvent(
        id: 'ev_unknown',
        subscriptionId: 'ajedrez_torneo',
        title: 'Torneo Relámpago de Ajedrez',
        competition: 'Ajedrez Master',
        startDateTime: DateTime.now(),
        broadcaster: 'Twitch ChessTV',
      );

      final matches = CalendarChannelMatcher.findMatchingChannels(event, allChannels);
      expect(matches, isEmpty);
    });

    test('matches DaddyLive channel directly via channelHints pluginChannelId', () {
      final daddyliveChannel = Channel(
        id: 'daddy_1027',
        name: 'Oneplay Sport 1 CZ',
        logoUrl: '',
        fallbackUrls: const [],
        category: 'Deportes',
        country: 'República Checa',
        pluginId: 'moai_daddylive',
        pluginChannelId: '1027',
        pluginTag: 'Daddy',
      );

      final event = CalendarEvent(
        id: 'ev_cup',
        subscriptionId: 'champions',
        title: 'Kladno vs Banik Ostrava',
        competition: 'Czech Cup',
        startDateTime: DateTime.now(),
        broadcaster: 'ESPN',
        channelHints: const ['1027'],
      );

      // Con canal de DaddyLive presente en la lista instalada:
      final matchesWithDaddy = CalendarChannelMatcher.findMatchingChannels(
        event,
        [daddyliveChannel, ...allChannels],
      );
      expect(matchesWithDaddy.map((c) => c.id), contains('daddy_1027'));

      // Sin canal de DaddyLive (usuario no tiene instalado el plugin de daddylive):
      final matchesWithoutDaddy = CalendarChannelMatcher.findMatchingChannels(
        event,
        allChannels,
      );
      expect(matchesWithoutDaddy.map((c) => c.id), isNot(contains('daddy_1027')));
      // Pero sí encuentra ESPN / canales deportivos disponibles
      expect(matchesWithoutDaddy.isNotEmpty, isTrue);
    });
  });
}
