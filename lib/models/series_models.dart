import 'package:moai3/models/movie_models.dart';

/// Una temporada de la serie: en el portal cada una es un ítem propio del
/// catálogo ("Serie T1", "Serie T2"…), con su `contentId`.
class SeriesSeason {
  const SeriesSeason({required this.contentId, required this.number});

  final String contentId;
  final int number;
}

/// Un capítulo de una temporada. El portal no trae título ni imagen: sólo el
/// número (`seriesNumber`) y, a veces, la duración.
class SeriesEpisode {
  const SeriesEpisode({
    required this.contentId,
    required this.number,
    this.duration,
  });

  final String contentId;
  final int number;
  final String? duration;
}

/// El detalle de una temporada (`v4/getItemData` con `type: "0"`): la ficha
/// (como la de una película), todas las temporadas de la serie y los
/// capítulos de ésta.
class SeriesSeasonDetail {
  const SeriesSeasonDetail({
    required this.info,
    required this.seasons,
    required this.episodes,
    this.audioInfo = '',
    this.subsInfo = '',
    this.plannedEpisodes,
    this.imdbId,
    this.originalCountry,
  });

  /// País de origen ("Japan", "United States of America"); sólo viene en el
  /// detalle. `null` si no dice.
  final String? originalCountry;

  final MovieItem info;

  /// Id de IMDb de la serie ("tt23112594", en `keyWords`): el mismo en
  /// todas las temporadas. Sólo viene en el detalle, no en el catálogo.
  final String? imdbId;

  /// Cuántos capítulos va a tener la temporada (`volumnCount`; los subidos
  /// son [episodes]): VisionQuest T1 decía 8 con 7 subidos. `null` si no
  /// dice.
  final int? plannedEpisodes;

  /// Faltan capítulos por subir después del [lastNumber] (el último que se
  /// vio): la serie no terminó, se espera el siguiente.
  bool expectsAfter(int lastNumber) => (plannedEpisodes ?? 0) > lastNumber;

  /// Audios y subtítulos de la temporada, como los manda el portal
  /// ("por,eng,spa", "pt,es,en"; "und" o "null" si no dice).
  final String audioInfo;
  final String subsInfo;

  /// Qué tan completa es esta versión: idiomas de audio y subtítulos, y
  /// sinopsis. Sirve para elegir entre dos versiones de la misma temporada.
  int get completeness {
    int count(String info) => info
        .split(',')
        .map((c) => c.trim().toLowerCase())
        .where((c) => c.isNotEmpty && c != 'und' && c != 'null')
        .length;
    final synopsis = (info.description ?? '').trim().isNotEmpty ? 1 : 0;
    return count(audioInfo) + count(subsInfo) + synopsis;
  }

  /// Las temporadas sin repetir número. A veces el portal lista dos
  /// versiones de la misma (en Bob's Burgers, la oficial con tres idiomas y
  /// una carga paralela grabada de la TV, sin idiomas): queda la más completa
  /// según [details]; mientras no se conocen, la primera.
  static List<SeriesSeason> bestSeasons(
    List<SeriesSeason> all,
    Map<String, SeriesSeasonDetail> details,
  ) {
    int score(SeriesSeason s) => details[s.contentId]?.completeness ?? -1;
    final best = <int, SeriesSeason>{};
    for (final season in all) {
      final current = best[season.number];
      if (current == null || score(season) > score(current)) {
        best[season.number] = season;
      }
    }
    return best.values.toList()..sort((a, b) => a.number.compareTo(b.number));
  }

  /// La serie para recomendar entre amigos: el mismo `contentId` en todos
  /// los TV, se entre por la temporada que se entre. Es la primera
  /// temporada y, si tiene dos versiones, la de `contentId` menor (sin
  /// depender de cuál se considere más completa). Sin lista, [fallback].
  static String recommendationKey(List<SeriesSeason> all, String fallback) {
    if (all.isEmpty) return fallback;
    final first = all.map((s) => s.number).reduce((a, b) => a < b ? a : b);
    final ids = [
      for (final s in all)
        if (s.number == first) s.contentId,
    ]..sort();
    return ids.first;
  }

  /// Los `contentId` de las temporadas cuyo número aparece más de una vez.
  static List<String> duplicated(List<SeriesSeason> all) {
    final byNumber = <int, List<String>>{};
    for (final s in all) {
      (byNumber[s.number] ??= []).add(s.contentId);
    }
    return [
      for (final ids in byNumber.values)
        if (ids.length > 1) ...ids,
    ];
  }

  /// Ordenadas por número. Trae también ésta.
  final List<SeriesSeason> seasons;

  /// Ordenados por número.
  final List<SeriesEpisode> episodes;

  /// Arma el detalle con el `assetData` de la respuesta; [info] es la ficha
  /// ya leída. `null` si no es un detalle.
  static SeriesSeasonDetail? fromAsset(Map asset, MovieItem info) {
    final seasons = <SeriesSeason>[
      for (final raw in (asset['sameSeasonSeriesList'] as List?) ?? const [])
        if (raw is Map)
          if ((raw['contentId']?.toString() ?? '', _int(raw['seasonNumber']))
              case (final id, final number?) when id.isNotEmpty)
            SeriesSeason(contentId: id, number: number),
    ]..sort((a, b) => a.number.compareTo(b.number));
    final episodes = <SeriesEpisode>[
      for (final raw in (asset['simpleProgramList'] as List?) ?? const [])
        if (raw is Map)
          if ((raw['contentId']?.toString() ?? '', _int(raw['seriesNumber']))
              case (final id, final number?) when id.isNotEmpty)
            SeriesEpisode(
              contentId: id,
              number: number,
              duration: switch (raw['duration']?.toString().trim()) {
                final d? when d.isNotEmpty => d,
                _ => null,
              },
            ),
    ]..sort((a, b) => a.number.compareTo(b.number));
    return SeriesSeasonDetail(
      info: info,
      seasons: seasons,
      episodes: episodes,
      audioInfo: asset['audioInfo']?.toString() ?? '',
      subsInfo: asset['subsInfo']?.toString() ?? '',
      plannedEpisodes: switch (_int(asset['volumnCount'])) {
        final n? when n > 0 => n,
        _ => null,
      },
      imdbId: _imdb.firstMatch('${asset['keyWords'] ?? ''}')?.group(0),
      originalCountry: switch (asset['originalCountry']?.toString().trim()) {
        final c? when c.isNotEmpty => c,
        _ => null,
      },
    );
  }

  static final RegExp _imdb = RegExp(r'tt\d+');

  static int? _int(Object? value) =>
      value is int ? value : int.tryParse('${value ?? ''}');

  /// "Caballos lentos T6" → "Caballos lentos"; "Slow Horses S6" → "Slow
  /// Horses". La temporada ya se ve en su lista.
  static String seriesTitle(String name) {
    final title = name.replaceFirst(_seasonSuffix, '').trim();
    return title.isEmpty ? name : title;
  }

  /// El número de temporada que dice el nombre o el alias ("Serie T13",
  /// "Series S13", "Temporada 13"); `null` si no dice.
  static int? seasonNumber(MovieItem item) {
    for (final text in [item.name, item.alias ?? '']) {
      if (_seasonSuffix.firstMatch(text.trim()) case final match?) {
        return int.tryParse(RegExp(r'\d+').firstMatch(match[0]!)![0]!);
      }
    }
    return null;
  }

  static final RegExp _seasonSuffix = RegExp(
    r'[\s\-–:]*\b(t|s|temporada|season)\s*\d+\s*$',
    caseSensitive: false,
  );
}
