/// Modelo que representa una película en el catálogo VOD de MoAI 3 (SPEC-38).
class Movie {
  final String id;
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double voteAverage;
  final String? imdbId;

  const Movie({
    required this.id,
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage = 0.0,
    this.imdbId,
  });

  /// Crea una instancia de [Movie] a partir de la respuesta JSON de TMDB API.
  factory Movie.fromTmdbJson(Map<String, dynamic> json) {
    final poster = json['poster_path'] as String?;
    final backdrop = json['backdrop_path'] as String?;

    return Movie(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? json['original_title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: poster != null && !poster.startsWith('http')
          ? 'https://image.tmdb.org/t/p/w500$poster'
          : poster,
      backdropPath: backdrop != null && !backdrop.startsWith('http')
          ? 'https://image.tmdb.org/t/p/w780$backdrop'
          : backdrop,
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      imdbId: json['imdb_id'] as String?,
    );
  }

  /// Crea una instancia de [Movie] a partir de la respuesta JSON de Cinemeta Stremio.
  factory Movie.fromCinemetaJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? '';
    final isImdb = rawId.startsWith('tt');

    return Movie(
      id: rawId,
      title: json['name'] as String? ?? json['title'] as String? ?? '',
      overview: json['description'] as String? ?? json['overview'] as String? ?? '',
      posterPath: json['poster'] as String?,
      backdropPath: json['background'] as String?,
      releaseDate: json['year']?.toString() ?? json['releaseInfo']?.toString(),
      voteAverage: json['imdbRating'] is num
          ? (json['imdbRating'] as num).toDouble()
          : (double.tryParse(json['imdbRating']?.toString() ?? '') ?? 0.0),
      imdbId: isImdb ? rawId : json['imdb_id'] as String?,
    );
  }

  /// Deserialización JSON genérica.
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['poster_path'] as String? ?? json['posterPath'] as String?,
      backdropPath: json['backdrop_path'] as String? ?? json['backdropPath'] as String?,
      releaseDate: json['release_date'] as String? ?? json['releaseDate'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ??
          (json['voteAverage'] as num?)?.toDouble() ??
          0.0,
      imdbId: json['imdb_id'] as String? ?? json['imdbId'] as String?,
    );
  }

  /// Convierte la instancia a un mapa JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      if (posterPath != null) 'poster_path': posterPath,
      if (backdropPath != null) 'backdrop_path': backdropPath,
      if (releaseDate != null) 'release_date': releaseDate,
      'vote_average': voteAverage,
      if (imdbId != null) 'imdb_id': imdbId,
    };
  }

  Movie copyWith({
    String? id,
    String? title,
    String? overview,
    String? posterPath,
    String? backdropPath,
    String? releaseDate,
    double? voteAverage,
    String? imdbId,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      releaseDate: releaseDate ?? this.releaseDate,
      voteAverage: voteAverage ?? this.voteAverage,
      imdbId: imdbId ?? this.imdbId,
    );
  }
}
