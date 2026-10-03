/// Modelo que representa una fuente de transmisión Torrent/P2P para una película (SPEC-38).
class TorrentStream {
  final String name;
  final String title;
  final String infoHash;
  final String magnetUrl;
  final int seeders;
  final int score;
  final bool hasLatinoAudio;
  final bool hasCastellanoAudio;
  final String quality;

  const TorrentStream({
    required this.name,
    required this.title,
    required this.infoHash,
    required this.magnetUrl,
    required this.seeders,
    required this.score,
    this.hasLatinoAudio = false,
    this.hasCastellanoAudio = false,
    this.quality = 'HD',
  });

  /// Extrae la cantidad de semillas (seeders) desde la cadena descriptiva (ej. "👤 142").
  static int extractSeeders(String text) {
    final match = RegExp(r'👤\s*(\d+)').firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }
    final matchAlt = RegExp(r's(?:eeders)?:?\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (matchAlt != null) {
      return int.tryParse(matchAlt.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  /// Extrae la calidad de video basada en el título (ej: 1080p, 720p, 4K).
  static String extractQuality(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('2160p') || lower.contains('4k')) return '4K';
    if (lower.contains('1080p') || lower.contains('fhd')) return '1080p';
    if (lower.contains('720p') || lower.contains('hd')) return '720p';
    return 'SD';
  }

  /// Calcula la puntuación dinámica de la fuente Torrent priorizando audio Latino y salud.
  static int calculateScore({
    required String title,
    required int seeders,
  }) {
    int score = 0;
    final lower = title.toLowerCase();

    // 1. PRIORIDAD MÁXIMA: Audio Latino
    final isLatino = lower.contains('latino') ||
        lower.contains('lat') ||
        lower.contains('dual') ||
        lower.contains('multi');
    final isCastellano = lower.contains('castellano') || lower.contains('español');

    if (isLatino) {
      score += 10000;
    } else if (isCastellano) {
      score += 5000;
    }

    // 2. Calidad de Video
    if (lower.contains('1080p') || lower.contains('fhd')) {
      score += 500;
    } else if (lower.contains('720p') || lower.contains('hd')) {
      score += 100;
    } else if (lower.contains('4k') || lower.contains('2160p')) {
      score += 50;
    }

    // 3. Salud de la fuente (Seeders * 10)
    score += seeders * 10;

    return score;
  }

  /// Deserializa la respuesta recibida desde Torrentio API (`/stream/movie/{imdb_id}.json`).
  factory TorrentStream.fromTorrentioJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? 'Torrentio';
    final rawTitle = json['title'] as String? ?? '';
    final infoHash = json['infoHash'] as String? ??
        (json['behaviorHints'] != null ? json['behaviorHints']['infoHash'] as String? : null) ??
        '';

    final url = json['url'] as String? ?? '';
    final magnetUrl = url.startsWith('magnet:')
        ? url
        : (infoHash.isNotEmpty
            ? 'magnet:?xt=urn:btih:$infoHash&dn=${Uri.encodeComponent(rawTitle)}'
            : url);

    final seeders = extractSeeders(rawTitle);
    final lower = rawTitle.toLowerCase();
    final isLatino = lower.contains('latino') ||
        lower.contains('lat') ||
        lower.contains('dual') ||
        lower.contains('multi');
    final isCastellano = lower.contains('castellano') || lower.contains('español');
    final quality = extractQuality(rawTitle);
    final computedScore = calculateScore(title: rawTitle, seeders: seeders);

    return TorrentStream(
      name: rawName,
      title: rawTitle,
      infoHash: infoHash,
      magnetUrl: magnetUrl,
      seeders: seeders,
      score: computedScore,
      hasLatinoAudio: isLatino,
      hasCastellanoAudio: isCastellano,
      quality: quality,
    );
  }

  factory TorrentStream.fromJson(Map<String, dynamic> json) {
    return TorrentStream(
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      infoHash: json['info_hash'] as String? ?? json['infoHash'] as String? ?? '',
      magnetUrl: json['magnet_url'] as String? ?? json['magnetUrl'] as String? ?? '',
      seeders: (json['seeders'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      hasLatinoAudio: json['has_latino_audio'] as bool? ?? json['hasLatinoAudio'] as bool? ?? false,
      hasCastellanoAudio: json['has_castellano_audio'] as bool? ?? json['hasCastellanoAudio'] as bool? ?? false,
      quality: json['quality'] as String? ?? 'HD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'info_hash': infoHash,
      'magnet_url': magnetUrl,
      'seeders': seeders,
      'score': score,
      'has_latino_audio': hasLatinoAudio,
      'has_castellano_audio': hasCastellanoAudio,
      'quality': quality,
    };
  }
}
