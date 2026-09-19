import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/models/channel.dart';

void main() {
  group('ChannelPlaybackHelpers', () {
    test('retorna todas las urls como fuentes de reproducción', () {
      final channel = Channel(
        id: '1',
        name: 'Test',
        logoUrl: '',
        country: 'AR',
        category: 'X',
        fallbackUrls: [
          'http://primary.m3u8',
          'http://backup.m3u8',
        ],
      );
      expect(
        ChannelPlaybackHelpers.playableUrls(channel),
        ['http://primary.m3u8', 'http://backup.m3u8'],
      );
      expect(
        ChannelPlaybackHelpers.currentUrl(channel, 0),
        'http://primary.m3u8',
      );
      expect(
        ChannelPlaybackHelpers.currentUrl(channel, 1),
        'http://backup.m3u8',
      );
    });

    test('fromJson acepta streamUrl y mapea a fallbackUrls', () {
      final channel = Channel.fromJson({
        'id': 'a',
        'name': 'A',
        'logoUrl': 'x',
        'streamUrl': 'http://stream.m3u8',
        'country': 'AR',
        'category': 'Aire',
      });
      expect(channel.fallbackUrls, ['http://stream.m3u8']);
      expect(channel.url, 'http://stream.m3u8');
    });

    test('playbackSourceLabel describe la fuente de Moai Server', () {
      final channel = Channel(
        id: 'tv',
        name: 'TV',
        logoUrl: '',
        fallbackUrls: [
          'https://cdn03.gigared.com.ar/live/TV_Publica.mpd',
        ],
      );
      expect(
        ChannelPlaybackHelpers.playbackSourceLabel(channel, 0),
        contains('Moai Server'),
      );
    });

    test('friendlyPlaybackError traduce el código 2004 a un error amigable de geobloqueo/HTTP status', () {
      expect(
        ChannelPlaybackHelpers.friendlyPlaybackError(2004, 'source error'),
        anyOf(
          contains('bloqueo por geolocalización'),
          equals('playback_error_bad_http_status'),
        ),
      );
      expect(
        ChannelPlaybackHelpers.friendlyPlaybackError(null, 'Response code: 403'),
        anyOf(
          contains('bloqueo geográfico'),
          equals('playback_error_http_auth'),
        ),
      );
      expect(
        ChannelPlaybackHelpers.friendlyPlaybackError(2002, null),
        anyOf(
          equals('timeout de red'),
          equals('playback_error_timeout'),
        ),
      );
      expect(
        ChannelPlaybackHelpers.friendlyPlaybackError(1002, null),
        anyOf(
          equals('fallo de conexión de red'),
          equals('playback_error_network'),
        ),
      );
    });
  });
}

