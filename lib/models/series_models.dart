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
  });

  final MovieItem info;

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
    return SeriesSeasonDetail(info: info, seasons: seasons, episodes: episodes);
  }

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
