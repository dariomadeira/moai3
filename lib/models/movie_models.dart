class CategoryColumn {
  final int columnId;
  final String columnName;
  final String? code;
  final List<MovieItem> movies;

  CategoryColumn({
    required this.columnId,
    required this.columnName,
    this.code,
    this.movies = const [],
  });

  factory CategoryColumn.fromJson(Map<String, dynamic> json) {
    var rawAssetList = json['assetList'] as List? ?? [];
    List<MovieItem> movieList = rawAssetList
        .whereType<Map<String, dynamic>>()
        .map((e) => MovieItem.fromJson(e))
        .toList();

    return CategoryColumn(
      columnId: json['columnId'] is int
          ? json['columnId']
          : int.tryParse(json['columnId']?.toString() ?? '0') ?? 0,
      columnName: json['alias']?.toString() ??
          json['name']?.toString() ??
          json['columnName']?.toString() ??
          'Categoría',
      code: json['code']?.toString(),
      movies: movieList,
    );
  }

  Map<String, dynamic> toJson() => {
    'columnId': columnId,
    'columnName': columnName,
    'code': code,
    'assetList': movies.map((m) => m.toJson()).toList(),
  };
}

class MovieItem {
  final String contentId;
  final String name;
  final String? alias;
  final String? poster;
  final String? score;
  final String? year;
  final String? description;
  final String? director;
  final String? actorDisplay;
  final String? duration;
  final String? tags;

  MovieItem({
    required this.contentId,
    required this.name,
    this.alias,
    this.poster,
    this.score,
    this.year,
    this.description,
    this.director,
    this.actorDisplay,
    this.duration,
    this.tags,
  });

  factory MovieItem.fromJson(Map<String, dynamic> json) {
    String? foundPoster;
    var rawPosterList = json['posterList'] as List? ?? [];
    if (rawPosterList.isNotEmpty) {
      for (var p in rawPosterList) {
        if (p is Map) {
          final type = p['fileType']?.toString().toLowerCase();
          final url = p['fileUrl']?.toString() ?? p['url']?.toString();
          if (url != null && url.isNotEmpty) {
            if (type == 'icon' || type == 'poster') {
              foundPoster = url;
              break;
            }
          }
        }
      }
      if (foundPoster == null && rawPosterList.first is Map) {
        foundPoster = (rawPosterList.first as Map)['fileUrl']?.toString() ??
            (rawPosterList.first as Map)['url']?.toString();
      }
    }

    foundPoster ??= json['poster']?.toString() ??
        json['posterUrl']?.toString() ??
        json['picUrl']?.toString();

    return MovieItem(
      contentId: json['contentId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Sin título',
      alias: json['alias']?.toString(),
      poster: foundPoster,
      score: json['score']?.toString(),
      year: json['year']?.toString() ??
          json['releaseYear']?.toString() ??
          (json['shelveTime'] as String?)?.split(' ').first,
      description: json['description']?.toString() ?? json['intro']?.toString(),
      director: json['director']?.toString(),
      actorDisplay: json['actorDisplay']?.toString() ?? json['actors']?.toString(),
      duration: json['duration']?.toString(),
      tags: json['tags']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'name': name,
    'alias': alias,
    'poster': poster,
    'score': score,
    'year': year,
    'description': description,
    'director': director,
    'actorDisplay': actorDisplay,
    'duration': duration,
    'tags': tags,
  };
}

/// Origen real del catálogo mostrado por la app.
enum CatalogSource {
  /// Descargado en vivo desde el servicio de catálogo (sesión válida).
  liveApi,

  /// Documento fresco generado por la app oficial en el almacenamiento del TV.
  localDocument,

  /// Última descarga en vivo que Moai guardó en su carpeta privada.
  savedCatalog,

  /// Respaldo empaquetado en los assets del APK (hardcodeado).
  assetBundle,
}

class CatalogResult {
  final List<CategoryColumn> categories;
  final bool isFromNetwork;
  final String statusMessage;
  final CatalogSource source;

  CatalogResult({
    required this.categories,
    required this.isFromNetwork,
    required this.statusMessage,
    this.source = CatalogSource.assetBundle,
  });

  /// `true` solo si el catálogo vino EN VIVO por la API (no caché local ni assets).
  bool get isFreshLive => source == CatalogSource.liveApi;

  /// `true` si el catálogo es el respaldo empaquetado (hardcodeado).
  bool get isHardcoded => source == CatalogSource.assetBundle;

  int get totalMovies =>
      categories.fold(0, (sum, cat) => sum + cat.movies.length);
}
