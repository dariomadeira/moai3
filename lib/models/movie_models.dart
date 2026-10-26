import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Textos traducidos que usa armar el catálogo. Se calculan en el hilo
/// principal ([CatalogStrings.current]) y viajan como texto común: así el
/// catálogo se puede armar en otro hilo, donde no hay traducciones.
class CatalogStrings {
  const CatalogStrings({
    required this.untitled,
    required this.defaultCategory,
    required this.trailersCategory,
  });

  /// Los del idioma actual.
  factory CatalogStrings.current() => CatalogStrings(
    untitled: LocaleKeys.movies_untitled.tr(),
    defaultCategory: LocaleKeys.movies_category_default.tr(),
    trailersCategory: LocaleKeys.movies_category_trailers.tr(),
  );

  /// Película sin nombre.
  final String untitled;

  /// Categoría sin nombre.
  final String defaultCategory;

  /// Cómo se llama la categoría de tráileres en Moai ("Adelantos").
  final String trailersCategory;
}

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

  /// Con [strings] se puede armar en otro hilo (sin ellos se traducen acá).
  factory CategoryColumn.fromJson(
    Map<String, dynamic> json, [
    CatalogStrings? strings,
  ]) {
    final texts = strings ?? CatalogStrings.current();
    final rawAssetList = json['assetList'] as List? ?? [];
    final List<MovieItem> movieList = rawAssetList
        .whereType<Map<String, dynamic>>()
        .map((m) => MovieItem.fromJson(m, untitled: texts.untitled))
        .toList();

    final rawName =
        json['name']?.toString() ??
        json['alias']?.toString() ??
        json['columnName']?.toString() ??
        texts.defaultCategory;
    final normalizedName = rawName.trim().toLowerCase() == 'all'
        ? 'Todos'
        // Los tráileres en Moai se llaman "adelantos".
        : normalizeText(rawName) == 'trailer'
        ? texts.trailersCategory
        : rawName.replaceAll(RegExp(r'\bAll\b', caseSensitive: false), 'Todos');

    return CategoryColumn(
      columnId: json['columnId'] is int
          ? json['columnId']
          : int.tryParse(json['columnId']?.toString() ?? '0') ?? 0,
      columnName: normalizedName,
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
  final String? backdrop;
  final List<String> backdrops;
  final String? score;
  final String? year;
  final String? description;
  final String? director;
  final String? actorDisplay;
  final String? duration;
  final String? tags;
  final String? programType;

  MovieItem({
    required this.contentId,
    required this.name,
    this.alias,
    this.poster,
    this.backdrop,
    this.backdrops = const [],
    this.score,
    this.year,
    this.description,
    this.director,
    this.actorDisplay,
    this.duration,
    this.tags,
    this.programType,
  });

  bool get isTrailer {
    final pt = (programType ?? '').toLowerCase().trim();
    return pt == 'trailer' || name.toLowerCase().contains('trailer');
  }

  bool get isSeries {
    final pt = (programType ?? '').toLowerCase().trim();
    return pt == 'teleplay' ||
        pt == 'series' ||
        pt == '0' ||
        RegExp(
          r'\b(t\d+|s\d+|temporada)\b',
          caseSensitive: false,
        ).hasMatch(name) ||
        RegExp(
          r'\b(s\d+|season)\b',
          caseSensitive: false,
        ).hasMatch(alias ?? '');
  }

  bool get isMovie => !isSeries && !isTrailer;

  /// "(Tráiler)", "Trailer:" y parecidos al principio del nombre.
  static final RegExp _trailerTag = RegExp(
    r'^\s*\(?\s*tr[aá]iler\s*\)?\s*[:\-–]?\s*',
    caseSensitive: false,
  );

  /// [title] sin la marca de tráiler del catálogo ("(Tráiler)Weapons" →
  /// "Weapons").
  static String withoutTrailerTag(String title) =>
      title.replaceFirst(_trailerTag, '').trim();

  /// Nombre para mostrar: en un tráiler (en Moai, "adelanto"), "Adelanto -
  /// Weapons".
  String get displayName => isTrailer
      ? LocaleKeys.movies_trailer_title.tr(
          namedArgs: {'name': withoutTrailerTag(name)},
        )
      : name;

  /// La misma película con otro año. El catálogo no trae el de estreno
  /// ([year] sale de `shelveTime`, cuándo se subió); cuando se conoce (p. ej.
  /// por TMDb) se reemplaza con éste.
  MovieItem withYear(String year) => MovieItem(
    contentId: contentId,
    name: name,
    alias: alias,
    poster: poster,
    backdrop: backdrop,
    backdrops: backdrops,
    score: score,
    year: year,
    description: description,
    director: director,
    actorDisplay: actorDisplay,
    duration: duration,
    tags: tags,
    programType: programType,
  );

  /// Imagen de fondo / horizontal preferida (fallback al poster)
  String? get effectiveBackdrop =>
      backdrop ?? (backdrops.isNotEmpty ? backdrops.first : poster);

  /// Lista de imágenes horizontales desduplicadas. Se calcula una vez: la
  /// piden la Hero, las miniaturas y el detalle en cada build.
  late final List<String> distinctBackdrops = _distinctBackdrops();

  List<String> _distinctBackdrops() {
    final list = <String>[];
    if (backdrop != null && backdrop!.trim().isNotEmpty) {
      list.add(backdrop!.trim());
    }
    for (final b in backdrops) {
      final trimmed = b.trim();
      if (trimmed.isNotEmpty && !list.contains(trimmed)) {
        list.add(trimmed);
      }
    }
    return List.unmodifiable(list);
  }

  /// Imagen para el fondo ambiental superior.
  /// Siempre devuelve la imagen principal de la película para garantizar que el
  /// fondo ambiental cargue SIEMPRE en todas las películas.
  String? get ambientBackdrop => effectiveBackdrop;

  /// Lista de imágenes para la tarjeta de reproducción (hero card).
  /// Si la película cuenta con fotos/escenas adicionales, excluye la imagen del fondo
  /// para que el carrusel rotativo no repita la imagen principal de arriba.
  /// Se calcula una vez.
  late final List<String> stageImages = _stageImages();

  List<String> _stageImages() {
    final ambient = ambientBackdrop;
    if (ambient != null) {
      final others = distinctBackdrops.where((u) => u != ambient).toList();
      if (others.isNotEmpty) return others;
    }
    if (distinctBackdrops.isNotEmpty) {
      return distinctBackdrops;
    }
    final fallback = effectiveBackdrop;
    if (fallback != null && fallback.trim().isNotEmpty) {
      return [fallback.trim()];
    }
    return const [];
  }

  /// Formatea la duración (ej. "02:22:00" -> "2h 22m", "01:45:00" -> "1h 45m")
  String? get formattedDuration {
    if (duration == null || duration!.trim().isEmpty) return null;
    final parts = duration!.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h > 0 && m > 0) return '${h}h ${m}m';
      if (h > 0) return '${h}h';
      if (m > 0) return '${m}m';
    }
    return duration;
  }

  static const Map<String, String> _genreSpanishMap = {
    'action': LocaleKeys.movies_genre_action,
    'adventure': LocaleKeys.movies_genre_adventure,
    'animation': LocaleKeys.movies_genre_animation,
    'anime': LocaleKeys.movies_genre_anime,
    'biography': LocaleKeys.movies_genre_biography,
    'comedy': LocaleKeys.movies_genre_comedy,
    'crime': LocaleKeys.movies_genre_crime,
    'documentary': LocaleKeys.movies_genre_documentary,
    'drama': LocaleKeys.movies_genre_drama,
    'family': LocaleKeys.movies_genre_family,
    'fantasy': LocaleKeys.movies_genre_fantasy,
    'film-noir': LocaleKeys.movies_genre_film_noir,
    'history': LocaleKeys.movies_genre_history,
    'horror': LocaleKeys.movies_genre_horror,
    'music': LocaleKeys.movies_genre_music,
    'musical': LocaleKeys.movies_genre_musical,
    'mystery': LocaleKeys.movies_genre_mystery,
    'romance': LocaleKeys.movies_genre_romance,
    'sci-fi': LocaleKeys.movies_genre_sci_fi,
    'science fiction': LocaleKeys.movies_genre_sci_fi,
    'short': LocaleKeys.movies_genre_short,
    'sport': LocaleKeys.movies_genre_sport,
    'superhero': LocaleKeys.movies_genre_superhero,
    'suspense': LocaleKeys.movies_genre_suspense,
    'thriller': LocaleKeys.movies_genre_suspense,
    'war': LocaleKeys.movies_genre_war,
    'western': LocaleKeys.movies_genre_western,
  };

  /// Lista limpia de géneros traducidos al castellano a partir de [tags]
  List<String> get genreList {
    if (tags == null || tags!.trim().isEmpty) return const [];
    return tags!
        .split(RegExp(r'[,/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && int.tryParse(s) == null)
        .map((raw) => _genreSpanishMap[raw.toLowerCase()]?.tr() ?? raw)
        .toList();
  }

  /// Puntuación formateada limpia (ej. "8.7", "6.6")
  String? get formattedScore {
    if (score == null || score!.trim().isEmpty) return null;
    final val = double.tryParse(score!.trim());
    if (val != null && val > 0) {
      return val.toStringAsFixed(1);
    }
    return score;
  }

  /// Año extraído de [year] o [shelveTime] (ej. "2026")
  String? get formattedYear {
    if (year != null && year!.trim().isNotEmpty) {
      final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(year!);
      if (yMatch != null) return yMatch.group(0);
    }
    return year;
  }

  /// [untitled]: el nombre si no trae ninguno (ya traducido, para armarla
  /// en otro hilo); sin él se traduce acá.
  factory MovieItem.fromJson(Map<String, dynamic> json, {String? untitled}) {
    String? foundPoster;
    String? foundBackdrop;
    final List<String> collectedBackdrops = [];
    final rawPosterList = json['posterList'] as List? ?? [];
    if (rawPosterList.isNotEmpty) {
      String? bestHighResIcon;
      String? bestStandardIcon;
      String? fallbackLandscape;
      final List<String> stageUrls = [];

      for (var p in rawPosterList) {
        if (p is Map) {
          final type = p['fileType']?.toString().toLowerCase().trim() ?? '';
          final size = p['size']?.toString().toLowerCase().trim() ?? '';
          final url = p['fileUrl']?.toString() ?? p['url']?.toString();
          if (url == null || url.trim().isEmpty) continue;

          final isPlaceholder =
              size.contains('100*100') || size.contains('100x100');

          if (type == 'icon') {
            if (!isPlaceholder && size.isNotEmpty) {
              bestHighResIcon ??= url;
            } else {
              bestStandardIcon ??= url;
            }
          } else if (type == 'poster') {
            fallbackLandscape ??= url;
            if (!collectedBackdrops.contains(url)) {
              collectedBackdrops.add(url);
            }
          } else if (type == 'stage') {
            stageUrls.add(url);
          }
        }
      }

      for (var s in stageUrls) {
        if (!collectedBackdrops.contains(s)) {
          collectedBackdrops.add(s);
        }
      }

      foundPoster =
          bestHighResIcon ??
          bestStandardIcon ??
          fallbackLandscape ??
          (stageUrls.isNotEmpty ? stageUrls.first : null);
      foundBackdrop =
          fallbackLandscape ?? (stageUrls.isNotEmpty ? stageUrls.first : null);

      if (foundPoster == null && rawPosterList.first is Map) {
        foundPoster =
            (rawPosterList.first as Map)['fileUrl']?.toString() ??
            (rawPosterList.first as Map)['url']?.toString();
      }
    }

    foundPoster ??=
        json['poster']?.toString() ??
        json['posterUrl']?.toString() ??
        json['picUrl']?.toString();
    foundBackdrop ??=
        json['backdrop']?.toString() ?? json['backdropUrl']?.toString();

    // Lo que guardó [toJson] (p. ej. favoritos): sin posterList, con la lista.
    if (rawPosterList.isEmpty && json['backdrops'] is List) {
      for (final b in json['backdrops'] as List) {
        final url = b?.toString() ?? '';
        if (url.trim().isNotEmpty && !collectedBackdrops.contains(url)) {
          collectedBackdrops.add(url);
        }
      }
    }

    if (foundBackdrop != null && !collectedBackdrops.contains(foundBackdrop)) {
      collectedBackdrops.insert(0, foundBackdrop);
    }

    return MovieItem(
      contentId: json['contentId']?.toString() ?? json['id']?.toString() ?? '',
      name:
          json['name']?.toString() ??
          json['title']?.toString() ??
          untitled ??
          LocaleKeys.movies_untitled.tr(),
      alias: json['alias']?.toString(),
      poster: foundPoster,
      backdrop: foundBackdrop,
      backdrops: collectedBackdrops,
      score: json['score']?.toString(),
      year:
          json['year']?.toString() ??
          json['releaseYear']?.toString() ??
          (json['shelveTime'] as String?)?.split(' ').first,
      description: json['description']?.toString() ?? json['intro']?.toString(),
      director: json['director']?.toString(),
      actorDisplay:
          json['actorDisplay']?.toString() ?? json['actors']?.toString(),
      duration: json['duration']?.toString(),
      tags: json['tags']?.toString(),
      programType: json['programType']?.toString() ?? json['type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'contentId': contentId,
    'name': name,
    'alias': alias,
    'poster': poster,
    'backdrop': backdrop,
    'backdrops': backdrops,
    'score': score,
    'year': year,
    'description': description,
    'director': director,
    'actorDisplay': actorDisplay,
    'duration': duration,
    'tags': tags,
    'programType': programType,
  };
}

/// Origen real del catálogo mostrado por la app.
enum CatalogSource {
  /// Descargado en vivo desde el servicio de catálogo (sesión válida).
  liveApi,

  /// Última descarga en vivo que Moai guardó en su carpeta privada.
  savedCatalog,

  /// Sin catálogo: la descarga falló o se canceló.
  none,
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
    this.source = CatalogSource.none,
  });

  /// `true` solo si el catálogo vino EN VIVO por la API.
  bool get isFreshLive => source == CatalogSource.liveApi;

  int get totalMovies =>
      categories.fold(0, (sum, cat) => sum + cat.movies.length);
}

/// Pista individual de video/audio de una calidad específica (viene de movieList[])
class VodMediaSource {
  final String mediaContentId;
  final String audioInfo;
  final String? audioType;
  final String? videoType;
  final String? videoFormat;
  final String? encodeFormat;
  final String? directUrl;
  final String? license;

  const VodMediaSource({
    required this.mediaContentId,
    required this.audioInfo,
    this.audioType,
    this.videoType,
    this.videoFormat,
    this.encodeFormat,
    this.directUrl,
    this.license,
  });

  factory VodMediaSource.fromJson(Map<String, dynamic> json) {
    String? foundLicense;
    if (json['licenseList'] is List &&
        (json['licenseList'] as List).isNotEmpty) {
      final l0 = (json['licenseList'] as List).first;
      if (l0 is Map) {
        foundLicense = l0['license']?.toString();
      }
    }
    return VodMediaSource(
      mediaContentId: json['contentId']?.toString() ?? '',
      audioInfo:
          json['audioInfo']?.toString() ?? LocaleKeys.movies_audio_default.tr(),
      audioType: json['audioType']?.toString(),
      videoType: json['videoType']?.toString(),
      videoFormat: json['videoFormat']?.toString(),
      encodeFormat: json['encodeFormat']?.toString(),
      directUrl:
          json['url']?.toString() ??
          json['playUrl']?.toString() ??
          json['streamUrl']?.toString() ??
          json['main_addr']?.toString() ??
          json['hlsUrl']?.toString(),
      license: foundLicense,
    );
  }

  bool get isLatino {
    final a = audioInfo.toLowerCase();
    return a.contains('latino') || a.contains('lat');
  }

  bool get isSpanish {
    final a = audioInfo.toLowerCase();
    return isLatino ||
        a.contains('español') ||
        a.contains('spanish') ||
        a.contains('castellano');
  }
}

/// Opción de calidad disponible para una película (1080P, 720P, etc.)
class VodQualityOption {
  final String quality;
  final List<VodMediaSource> sources;

  const VodQualityOption({required this.quality, required this.sources});

  factory VodQualityOption.fromJson(Map<String, dynamic> json) {
    final list = (json['movieList'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VodMediaSource.fromJson)
        .where((s) => s.mediaContentId.isNotEmpty)
        .toList();
    return VodQualityOption(
      quality:
          json['quality']?.toString() ?? LocaleKeys.movies_quality_auto.tr(),
      sources: list,
    );
  }

  /// Selecciona la mejor pista de audio: primero Latino, luego Español, luego la primera
  VodMediaSource? get bestAudioSource {
    if (sources.isEmpty) return null;
    return sources.firstWhere(
      (s) => s.isLatino,
      orElse: () =>
          sources.firstWhere((s) => s.isSpanish, orElse: () => sources.first),
    );
  }
}

/// Subtítulo disponible para una película
class VodSubtitleOption {
  final String name;
  final String language;
  final String url;

  const VodSubtitleOption({
    required this.name,
    required this.language,
    required this.url,
  });

  factory VodSubtitleOption.fromJson(Map<String, dynamic> json) {
    String url =
        json['url']?.toString() ?? json['subTitleUrl']?.toString() ?? '';
    final file = json['file'];
    if (url.isEmpty && file is List && file.isNotEmpty) {
      final f0 = file.first;
      if (f0 is Map) {
        url = f0['url']?.toString() ?? '';
      }
    }
    // La API suele mandar `file` como texto con forma de lista de Python:
    // "[{'url': 'http://…/x.srt', 'fileType': 'srt'}]".
    if (url.isEmpty && file is String) {
      url = RegExp(r'''https?://[^'"\s,\]}]+''').firstMatch(file)?[0] ?? '';
    }
    return VodSubtitleOption(
      name:
          json['name']?.toString() ??
          json['subTitleName']?.toString() ??
          (json['language']?.toString() ??
              LocaleKeys.movies_subtitle_default.tr()),
      language: json['language']?.toString() ?? '',
      url: url,
    );
  }

  /// Tipo MIME para ExoPlayer según la extensión ("srt" por defecto, que es
  /// lo que manda la API).
  String get mimeType => url.toLowerCase().split('?').first.endsWith('.vtt')
      ? 'text/vtt'
      : 'application/x-subrip';

  /// Prioridad 1: Latinoamericano
  bool get isLatino {
    final n = '$name $language'.toLowerCase();
    return n.contains('latino') ||
        n.contains('es-419') ||
        n.contains('es-la') ||
        n.contains('latin');
  }

  /// Prioridad 2: Español neutro
  bool get isSpanishNeutral {
    final n = '$name $language'.toLowerCase();
    return !isLatino &&
        (n.contains('español') || n.contains('spanish') || n == 'es');
  }

  /// Prioridad 3: Castellano / España
  bool get isCastellano {
    final n = '$name $language'.toLowerCase();
    return n.contains('castellano') ||
        n.contains('es-es') ||
        n.contains('spain') ||
        n.contains('españa');
  }

  bool get isAnySpanish => isLatino || isSpanishNeutral || isCastellano;
}

/// Información completa de reproducción devuelta por `startPlayVOD` (v10)
class VodPlayInfo {
  final String name;
  final List<VodQualityOption> qualities;
  final List<VodSubtitleOption> subtitles;

  const VodPlayInfo({
    required this.name,
    required this.qualities,
    required this.subtitles,
  });

  factory VodPlayInfo.fromJson(Map<String, dynamic> json) {
    final epList = json['episodeList'] as List? ?? [];
    final ep0 = epList.isNotEmpty && epList.first is Map<String, dynamic>
        ? epList.first as Map<String, dynamic>
        : <String, dynamic>{};

    final rawQualities = (ep0['totalMovieList'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VodQualityOption.fromJson)
        .where((q) => q.sources.isNotEmpty)
        .toList();

    final rawSubtitles = (ep0['subtitleList'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(VodSubtitleOption.fromJson)
        .where((s) => s.url.isNotEmpty)
        .toList();

    return VodPlayInfo(
      name: json['name']?.toString() ?? '',
      qualities: rawQualities,
      subtitles: rawSubtitles,
    );
  }

}

/// Datos finales de reproducción listos para inicializar el motor de video
class ResolvedPlayStream {
  final String streamUrl;
  final String quality;
  final String audioInfo;

  /// Subtítulos de la película (con URL); cuál mostrar lo elige el
  /// reproductor según el ajuste.
  final List<VodSubtitleOption> subtitles;
  final Map<String, String> headers;

  const ResolvedPlayStream({
    required this.streamUrl,
    required this.quality,
    required this.audioInfo,
    this.subtitles = const [],
    this.headers = const {},
  });

  /// Alias de conveniencia para la URL directa del stream
  String get directHlsUrl => streamUrl;
}
