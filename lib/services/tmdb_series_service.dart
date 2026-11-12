import 'package:moai3/services/tmdb_trailers_service.dart';

/// Lo que dice TMDb de una serie: si sigue (habrá más temporadas) y, si ya
/// está anunciada, cuándo sale el próximo capítulo.
class TmdbSeriesStatus {
  const TmdbSeriesStatus({
    required this.continues,
    required this.seasons,
    this.nextAirDate,
    this.nextSeason,
  });

  /// En emisión, en producción o planeada; `false` si terminó o se canceló.
  final bool continues;

  /// Temporadas que tiene (emitidas o anunciadas).
  final int seasons;

  /// El próximo capítulo anunciado: su fecha y de qué temporada es.
  final DateTime? nextAirDate;
  final int? nextSeason;
}

/// Estado de una serie en TMDb por su id de IMDb (el portal lo manda en
/// `keyWords` del detalle): `/find` da la serie exacta, sin buscar por
/// nombre, y `/tv/{id}` su estado. Dos pedidos por serie.
class TmdbSeriesService {
  /// [fetchJson] se reemplaza en los tests.
  TmdbSeriesService({TmdbJsonFetcher? fetchJson})
    : _fetchJson = fetchJson ?? TmdbTrailersService.httpFetch;

  final TmdbJsonFetcher _fetchJson;

  /// Estados de TMDb de una serie que sigue.
  static const Set<String> _continuing = {
    'Returning Series',
    'In Production',
    'Planned',
    'Pilot',
  };

  /// `null` si TMDb no contestó o no conoce ese id.
  Future<TmdbSeriesStatus?> statusOf(String imdbId) async {
    final found = await _fetchJson('/find/$imdbId', {
      'external_source': 'imdb_id',
    });
    final results = found?['tv_results'];
    final id = results is List && results.isNotEmpty && results.first is Map
        ? (results.first as Map)['id']
        : null;
    if (id == null) return null;
    final tv = await _fetchJson('/tv/$id', const {});
    if (tv == null) return null;
    final next = tv['next_episode_to_air'];
    return TmdbSeriesStatus(
      continues: _continuing.contains(tv['status']),
      seasons: tv['number_of_seasons'] as int? ?? 0,
      nextAirDate: next is Map
          ? DateTime.tryParse('${next['air_date'] ?? ''}')
          : null,
      nextSeason: next is Map ? next['season_number'] as int? : null,
    );
  }
}
