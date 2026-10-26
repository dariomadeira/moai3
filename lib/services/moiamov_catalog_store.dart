import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El catálogo bajado del portal, guardado en el disco privado de la app:
/// una copia por sección y la fecha de la última descarga completa.
///
/// Leer y escribir los archivos (cientos de KB) va en otro hilo.
class MoiamovCatalogStore {
  MoiamovCatalogStore(this._log);

  /// Dónde van los avisos (el log de Moiamov).
  final void Function(String) _log;

  /// Secciones que se guardan.
  static const Set<String> sections = {
    'masnew_movies',
    'masnew_featured',
    'masnew_series',
  };

  static const String _dateKey = 'moiamov_catalog_date';

  Directory? _directoryOverride;

  /// Carpeta de prueba. En la app se usa el directorio privado de soporte.
  /// (La usa `MoiamovApiService.debugSetCatalogDirectory`.)
  void debugSetDirectory(Directory? directory) {
    _directoryOverride = directory;
  }

  Future<Directory> _directory() async {
    final override = _directoryOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/catalog');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// Nombre visible de la sección ("Películas", "Series"…).
  static String sectionLabel(String section) => switch (section) {
    'masnew_featured' => LocaleKeys.movies_panel_featured_title.tr(),
    'masnew_series' => LocaleKeys.movies_panel_series_title.tr(),
    _ => LocaleKeys.movies_panel_movies_title.tr(),
  };

  /// Dónde se guarda [section] (null si no es una sección que se guarda).
  Future<String?> pathFor(String section) async {
    if (!sections.contains(section)) return null;
    final dir = await _directory();
    return '${dir.path}/$section.json';
  }

  /// Procesa una respuesta de getNextColumns entera: lee el JSON, descifra
  /// `data` con [key], cuenta lo que trae y, si trae títulos y hay
  /// [savePath], la guarda en disco. Corre en otro hilo ([Isolate.run]):
  /// sólo usa funciones puras y devuelve un resumen chico (las películas se
  /// arman recién al abrir la sección, desde el disco).
  static CatalogDownload processDownload(
    Uint8List body, {
    required String key,
    String? savePath,
  }) {
    final decoded = jsonDecode(utf8.decode(body, allowMalformed: true));
    if (decoded is! Map<String, dynamic>) return const CatalogDownload();
    final returnCode = decoded['returnCode']?.toString();
    final errorMessage = decoded['errorMessage']?.toString();
    if (returnCode != '0' && returnCode != '0000' && returnCode != '200') {
      return CatalogDownload(
        returnCode: returnCode,
        errorMessage: errorMessage,
      );
    }

    Object? inner = decoded['data'];
    String? decryptError;
    if (inner is String && inner.trim().isNotEmpty) {
      try {
        inner = jsonDecode(MoiamovCrypto.decrypt(inner.trim(), key));
      } catch (e) {
        inner = null;
        decryptError = '$e';
      }
    }
    final List? rawList;
    if (inner is Map<String, dynamic> && inner['recommendList'] is List) {
      rawList = inner['recommendList'] as List;
    } else if (decoded['recommendList'] is List) {
      rawList = decoded['recommendList'] as List;
    } else {
      rawList = null;
    }

    var categories = 0;
    var titles = 0;
    for (final column in rawList ?? const []) {
      if (column is! Map) continue;
      final assets = column['assetList'];
      final count = assets is List ? assets.whereType<Map>().length : 0;
      if (count > 0) {
        categories++;
        titles += count;
      }
    }

    var saved = false;
    if (titles > 0 && savePath != null) {
      File(
        savePath,
      ).writeAsStringSync(jsonEncode({'recommendList': rawList}), flush: true);
      saved = true;
    }
    return CatalogDownload(
      returnCode: returnCode,
      errorMessage: errorMessage,
      decryptError: decryptError,
      categories: categories,
      titles: titles,
      saved: saved,
    );
  }

  /// Fecha del catálogo: se guarda solo cuando bajan las 3 secciones.
  /// Null si todavía no hubo una descarga completa.
  Future<DateTime?> lastSavedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dateKey);
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (e) {
      _log('No se pudo leer la fecha del catálogo: $e');
      return null;
    }
  }

  Future<void> saveDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, date.toIso8601String());
  }

  /// Secciones que tienen una descarga guardada en disco.
  Future<Set<String>> savedSections() async {
    final saved = <String>{};
    try {
      final dir = await _directory();
      for (final section in sections) {
        final file = File('${dir.path}/$section.json');
        if (file.existsSync() && file.lengthSync() >= 50) saved.add(section);
      }
    } catch (e) {
      _log('No se pudo revisar el catálogo guardado: $e');
    }
    return saved;
  }

  /// Lee la última descarga guardada de [section].
  Future<CatalogResult?> load(String section) async {
    if (!sections.contains(section)) return null;
    try {
      final dir = await _directory();
      final file = File('${dir.path}/$section.json');
      if (!file.existsSync() || file.lengthSync() < 50) return null;

      // Cientos de KB y cientos de películas: leer el archivo y armarlas va
      // en otro hilo, para que el Inicio no se trabe al aparecer. Los textos
      // traducidos van desde acá (allá no hay traducciones).
      final path = file.path;
      final strings = CatalogStrings.current();
      final categories = await Isolate.run(
        () => parseCategories(File(path).readAsStringSync(), strings),
      );
      if (categories.isEmpty) return null;
      final result = CatalogResult(
        categories: categories,
        isFromNetwork: false,
        source: CatalogSource.savedCatalog,
        statusMessage: LocaleKeys.movies_catalog_from_saved.tr(
          namedArgs: {'section': sectionLabel(section)},
        ),
      );
      _log(
        'Última descarga guardada: ${result.totalMovies} títulos ($section).',
      );
      return result;
    } catch (e) {
      _log('No se pudo leer la copia guardada de $section: $e');
      return null;
    }
  }

  /// Arma las categorías con películas de un `{recommendList: [...]}`
  /// guardado ([raw] es el texto del archivo). Pura: corre en otro hilo.
  static List<CategoryColumn> parseCategories(
    String raw,
    CatalogStrings strings,
  ) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> || decoded['recommendList'] is! List) {
      return const [];
    }
    return [
      for (final column in decoded['recommendList'] as List)
        if (column is Map<String, dynamic>)
          if (CategoryColumn.fromJson(column, strings) case final category
              when category.movies.isNotEmpty)
            category,
    ];
  }
}

/// Resumen de una descarga del catálogo ([MoiamovCatalogStore.processDownload]).
class CatalogDownload {
  const CatalogDownload({
    this.returnCode,
    this.errorMessage,
    this.decryptError,
    this.categories = 0,
    this.titles = 0,
    this.saved = false,
  });

  /// Lo que respondió el portal (null: la respuesta no era un JSON válido).
  final String? returnCode;
  final String? errorMessage;

  /// No se pudo descifrar `data`.
  final String? decryptError;

  /// Categorías con títulos y cuántos títulos en total.
  final int categories;
  final int titles;

  /// Quedó guardada en disco.
  final bool saved;

  bool get ok =>
      returnCode == '0' || returnCode == '0000' || returnCode == '200';
}
