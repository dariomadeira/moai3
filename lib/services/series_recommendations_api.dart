import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tabla de recomendaciones de series en Supabase (migración 008): como la
/// de películas, aparte, con la temporada a la que llegó quien recomienda.
///
/// Las filas se leen con los mismos nombres que las de películas (la serie
/// en `movie`, con `seasonReached` adentro) para que el proveedor las trate
/// igual.
class SeriesRecommendationsApi extends MovieRecommendationsApi {
  static const String _table = 'series_recommendations';
  static const int _maxRows = 40;
  static const Duration _maxAge = Duration(days: 60);

  /// Dentro del JSON de la serie: la última temporada votada.
  static const String seasonKey = 'seasonReached';

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async {
    final rows = await _client
        .from(_table)
        .select(
          'recommender_device_id, content_id, series, season_number, '
          'created_at',
        )
        .inFilter('recommender_device_id', friendIds)
        .gte(
          'created_at',
          DateTime.now().toUtc().subtract(_maxAge).toIso8601String(),
        )
        .order('created_at')
        .limit(_maxRows);
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        {
          ...row,
          'movie': {
            ...?(row['series'] as Map?)?.cast<String, dynamic>(),
            seasonKey: row['season_number'],
          },
        },
    ];
  }

  @override
  Future<void> recommend(String deviceId, MovieItem movie) =>
      recommendJson(deviceId, movie.toJson());

  @override
  Future<void> recommendJson(String deviceId, Map<String, dynamic> json) async {
    await _client.from(_table).upsert({
      'recommender_device_id': deviceId,
      'content_id': json['contentId'],
      'series': json,
      'season_number': json[seasonKey],
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'recommender_device_id,content_id');
  }

  @override
  Future<void> remove(String deviceId, String contentId) async {
    await _client
        .from(_table)
        .delete()
        .eq('recommender_device_id', deviceId)
        .eq('content_id', contentId);
  }
}
