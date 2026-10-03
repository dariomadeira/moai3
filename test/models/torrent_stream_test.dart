import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/torrent_stream.dart';

void main() {
  group('TorrentStream Model & Scoring Tests (SPEC-38)', () {
    test('extractSeeders extrae correctamente el número de semillas', () {
      expect(TorrentStream.extractSeeders('Torrentio 1080p DUAL Latino\n👤 142 💾 2.1 GB'), 142);
      expect(TorrentStream.extractSeeders('Stream title seeders: 55'), 55);
      expect(TorrentStream.extractSeeders('Sin datos de semillas'), 0);
    });

    test('calculateScore da prioridad absoluta (+10,000) a audio latino', () {
      final scoreLatino = TorrentStream.calculateScore(
        title: 'Movie.2024.1080p.DUAL.Latino \n👤 50',
        seeders: 50,
      );

      final scoreIngles = TorrentStream.calculateScore(
        title: 'Movie.2024.1080p.English \n👤 500',
        seeders: 500,
      );

      // Audio latino (+10000 + 500 + 500 = 11000) vs Inglés (+500 + 5000 = 5500)
      expect(scoreLatino > scoreIngles, true);
    });

    test('fromTorrentioJson mapea correctamente campos y calcula score', () {
      final json = {
        'name': 'Torrentio 1080p',
        'title': 'Matrix.1999.1080p.DUAL.Latino.mkv\n👤 88 💾 3.5 GB',
        'infoHash': 'abc123def456',
        'url': 'magnet:?xt=urn:btih:abc123def456',
      };

      final stream = TorrentStream.fromTorrentioJson(json);

      expect(stream.name, 'Torrentio 1080p');
      expect(stream.infoHash, 'abc123def456');
      expect(stream.seeders, 88);
      expect(stream.hasLatinoAudio, true);
      expect(stream.quality, '1080p');
      expect(stream.score, greaterThanOrEqualTo(10000));
    });
  });
}
