import 'package:moai3/models/movie_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Tabla de recomendaciones en Supabase (SPEC-51).
class MovieRecommendationsApi {
  static const String _table = 'movie_recommendations';
  static const int _maxRows = 40;
  static const Duration _maxAge = Duration(days: 60);

  SupabaseClient get _client => Supabase.instance.client;

  /// Las últimas de [friendIds], la más nueva primero.
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async {
    final rows = await _client
        .from(_table)
        .select('recommender_device_id, content_id, movie, created_at')
        .inFilter('recommender_device_id', friendIds)
        .gte(
          'created_at',
          DateTime.now().toUtc().subtract(_maxAge).toIso8601String(),
        )
        .order('created_at')
        .limit(_maxRows);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> recommend(String deviceId, MovieItem movie) async {
    await _client.from(_table).upsert({
      'recommender_device_id': deviceId,
      'content_id': movie.contentId,
      'movie': movie.toJson(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'recommender_device_id,content_id');
  }

  /// Lo que manda el proveedor (lo guardado como pendiente): la película.
  /// Las series lo reemplazan para mandar también la temporada.
  Future<void> recommendJson(String deviceId, Map<String, dynamic> json) =>
      recommend(deviceId, MovieItem.fromJson(json));

  Future<void> remove(String deviceId, String contentId) async {
    await _client
        .from(_table)
        .delete()
        .eq('recommender_device_id', deviceId)
        .eq('content_id', contentId);
  }
}
