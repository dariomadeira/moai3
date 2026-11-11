import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/services/series_continue_service.dart';
import 'package:moai3/services/series_recommendations_api.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';

/// Recomendaciones de series entre amigos: lo mismo que películas
/// ([MovieRecommendationsProvider]) con su propia tabla y su propio
/// guardado. La recomendación es de la serie; cada 👍 lleva hasta qué
/// temporada llegó quien recomienda ([SeriesRecommendationsApi.seasonKey]).
///
/// No se muestran las series que ya se empezaron (están en "Seguir
/// series").
class SeriesRecommendationsProvider extends MovieRecommendationsProvider {
  /// [api] e [isWatched] los reemplazan los tests; por defecto, la tabla de
  /// series y [startedSeries] (nunca la de películas).
  SeriesRecommendationsProvider({
    MovieRecommendationsApi? api,
    Future<bool> Function(String contentId)? isWatched,
  }) : super(
         api: api ?? SeriesRecommendationsApi(),
         isWatched: isWatched ?? startedSeries,
         storageKey: 'series_recommendations_state',
       );

  /// La serie de [contentId] (una temporada) ya se empezó.
  static Future<bool> startedSeries(String contentId) async {
    for (final entry in await SeriesContinueService.entries()) {
      if (entry.current.seasonId == contentId ||
          entry.seasons.any((s) => s.contentId == contentId)) {
        return true;
      }
    }
    return false;
  }
}
