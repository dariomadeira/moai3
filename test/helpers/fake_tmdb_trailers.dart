import 'package:moai3/services/tmdb_trailers_service.dart';

/// Video de YouTube como lo trae TMDb en `videos.results`.
Map<String, dynamic> tmdbVideo(
  String key, {
  String type = 'Trailer',
  String lang = 'en',
  bool official = true,
  String published = '2026-10-01T10:00:00.000Z',
  String site = 'YouTube',
}) => {
  'key': key,
  'site': site,
  'type': type,
  'iso_639_1': lang,
  'official': official,
  'published_at': published,
};

/// Detalle de una película de TMDb con sus videos.
Map<String, dynamic> tmdbMovie(
  int id,
  String title, {
  List<Map<String, dynamic>> videos = const [],
  String? backdrop = '/fondo.jpg',
  String overview = 'De qué trata.',
  String release = '2026-11-20',
}) => {
  'id': id,
  'title': title,
  'original_title': title,
  'overview': overview,
  'release_date': release,
  'poster_path': '/poster.jpg',
  'backdrop_path': backdrop,
  'vote_average': 7.25,
  'genres': [
    {'id': 28, 'name': 'Acción'},
  ],
  'videos': {'results': videos},
};

/// TMDb falso: cartelera y próximos estrenos con [nowPlaying] y [upcoming]
/// (ids) y el detalle de cada una en [movies]. Lo que no está en [movies]
/// "no contesta". [calls] junta cada pedido (`/movie/now_playing`, `/movie/7`…).
TmdbTrailersService fakeTmdbTrailers({
  List<int> nowPlaying = const [],
  List<int> upcoming = const [],
  Map<int, Map<String, dynamic>> movies = const {},
  List<String>? calls,
  bool offline = false,
}) => TmdbTrailersService(
  fetchJson: (path, query) async {
    calls?.add(path);
    if (offline) return null;
    List<Map<String, int>> ids(List<int> list) => [
      for (final id in list) {'id': id},
    ];
    if (path == '/movie/now_playing') return {'results': ids(nowPlaying)};
    if (path == '/movie/upcoming') return {'results': ids(upcoming)};
    final id = int.tryParse(path.replaceFirst('/movie/', ''));
    return movies[id];
  },
);
