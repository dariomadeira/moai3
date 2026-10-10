import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';

class ArcadeRomManagerService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.infomak.moai/arcade_channel');
  static const String _activeRomKey = 'arcade_active_rom_filename';

  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/dariomadeira/moai_roms/main/manifest.json';
  static const String localEmulatorManifestUrl =
      'http://10.0.2.2:8080/manifest.json';

  List<ArcadeRomItem> _catalog = [];
  List<ArcadeRomItem> _installedRoms = [];
  String? _activeRomFilename;
  bool _isLoading = false;
  String? _errorMessage;

  // Seguimiento de descargas activas: filename -> porcentaje 0.0 - 1.0
  final Map<String, double> _downloadProgress = {};

  List<ArcadeRomItem> get catalog => _catalog;
  List<ArcadeRomItem> get installedRoms => _installedRoms;
  String? get activeRomFilename => _activeRomFilename;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, double> get downloadProgress => _downloadProgress;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _activeRomFilename = prefs.getString(_activeRomKey);
    await refreshInstalledRoms();
  }

  /// Consulta las ROMs presentes en el almacenamiento interno de la app.
  Future<List<ArcadeRomItem>> refreshInstalledRoms() async {
    try {
      final List<dynamic>? rawList =
          await _channel.invokeListMethod('getInstalledRoms');
      final List<ArcadeRomItem> list = [];
      if (rawList != null) {
        for (final item in rawList) {
          if (item is Map) {
            final filename = item['filename'] as String? ?? '';
            final path = item['path'] as String? ?? '';
            final sizeBytes = (item['sizeBytes'] as num?)?.toInt() ?? 0;
            final label = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            list.add(
              ArcadeRomItem(
                id: filename,
                name: _nameFromFilename(filename),
                filename: filename,
                sizeBytes: sizeBytes,
                sizeLabel: label,
                url: '',
                isInstalled: true,
                localPath: path,
                localSizeBytes: sizeBytes,
              ),
            );
          }
        }
      }
      _installedRoms = list;
      // Si la ROM activa ya no existe, o si no hay ninguna activa pero hay instaladas, ajustar
      if (_installedRoms.isNotEmpty) {
        if (_activeRomFilename == null ||
            !_installedRoms.any((r) => r.filename == _activeRomFilename)) {
          await setActiveRom(_installedRoms.first.filename);
        }
      } else {
        _activeRomFilename = null;
      }
      _updateCatalogInstalledFlags();
      notifyListeners();
      return _installedRoms;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeRomManagerService] Error al listar ROMs: $e');
      }
      return [];
    }
  }

  /// Descarga y parsea el archivo manifest.json desde un repositorio remoto o local.
  Future<bool> fetchCatalog([String url = defaultManifestUrl]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        _errorMessage = 'arcade_err_catalog_http'.tr(namedArgs: {
          'code': response.statusCode.toString(),
        });
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final body = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
      final List<dynamic> gamesJson = (data['games'] ?? data['juegos'] ?? []) as List<dynamic>;
      final baseUri = Uri.parse(url);
      _catalog = gamesJson.map((g) {
        final item = ArcadeRomItem.fromJson(g as Map<String, dynamic>);
        if (item.url.isNotEmpty &&
            !item.url.startsWith('http://') &&
            !item.url.startsWith('https://')) {
          final resolvedUri = baseUri.resolve(item.url);
          return item.copyWith(url: resolvedUri.toString());
        }
        return item;
      }).toList();

      await refreshInstalledRoms();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'arcade_err_repo_connect'.tr(namedArgs: {
        'error': e.toString(),
      });
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Descarga un archivo .zip al almacenamiento interno con reporte de progreso.
  Future<bool> downloadRom(
    ArcadeRomItem item, {
    void Function(double progress)? onProgress,
  }) async {
    if (item.url.isEmpty) return false;

    final String filename = item.filename;
    _downloadProgress[filename] = 0.0;
    notifyListeners();

    try {
      final String romDir =
          await _channel.invokeMethod('getRomDirectory') as String? ?? '';
      if (romDir.isEmpty) throw Exception('arcade_err_internal_dir'.tr());

      final targetFile = File('$romDir/$filename');
      final tempFile = File('$romDir/$filename.part');

      final client = HttpClient()
        ..badCertificateCallback = ((cert, host, port) => true);
      final request = await client.getUrl(Uri.parse(item.url));
      final response = await request.close();

      if (response.statusCode != 200) {
        _downloadProgress.remove(filename);
        notifyListeners();
        throw Exception('arcade_err_download_http'.tr(namedArgs: {
          'code': response.statusCode.toString(),
        }));
      }

      final contentLength = response.contentLength;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();
      await response.forEach((chunk) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          final progress = (receivedBytes / contentLength).clamp(0.0, 1.0);
          _downloadProgress[filename] = progress;
          onProgress?.call(progress);
          notifyListeners();
        }
      });
      await sink.flush();
      await sink.close();

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      // Regla de negocio Arcade: Solo se permite 1 juego instalado a la vez.
      // Borramos cualquier otra ROM previa del almacenamiento interno.
      for (final installed in _installedRoms) {
        if (installed.filename != filename) {
          try {
            await _channel.invokeMethod('deleteRom', {'name': installed.filename});
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[ArcadeRomManagerService] Error purgando ROM anterior ${installed.filename}: $e');
            }
          }
        }
      }

      _downloadProgress.remove(filename);
      await setActiveRom(filename);
      await refreshInstalledRoms();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeRomManagerService] Error descargando $filename: $e');
      }
      _downloadProgress.remove(filename);
      _errorMessage = 'Error al descargar $filename: $e';
      notifyListeners();
      return false;
    }
  }

  /// Elimina una ROM del almacenamiento interno para liberar espacio de disco.
  Future<bool> deleteRom(String filename) async {
    try {
      final bool result =
          await _channel.invokeMethod('deleteRom', {'name': filename}) ?? false;
      if (result) {
        if (_activeRomFilename == filename) {
          _activeRomFilename = null;
        }
        await refreshInstalledRoms();
      }
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeRomManagerService] Error borrando $filename: $e');
      }
      return false;
    }
  }

  /// Establece cuál es la ROM activa actual seleccionada para jugar.
  Future<void> setActiveRom(String filename) async {
    _activeRomFilename = filename;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRomKey, filename);
    notifyListeners();
  }

  /// Obtiene la ruta absoluta de la ROM activa actual, o null si no hay ninguna instalada.
  String? getActiveRomPath() {
    if (_activeRomFilename == null) return null;
    final item = _installedRoms.firstWhere(
      (r) => r.filename == _activeRomFilename,
      orElse: () => _installedRoms.isNotEmpty
          ? _installedRoms.first
          : const ArcadeRomItem(id: '', name: '', filename: '', url: ''),
    );
    return item.localPath;
  }

  String _nameFromFilename(String filename) {
    if (filename == 'mvsc.zip') return 'Marvel vs. Capcom: Clash of Super Heroes';
    if (filename == 'sfa3.zip') return 'Street Fighter Alpha 3';
    if (filename == 'vsav.zip') return 'Vampire Savior: The Lord of Vampire';
    return filename.replaceAll('.zip', '').toUpperCase();
  }

  void _updateCatalogInstalledFlags() {
    for (var i = 0; i < _catalog.length; i++) {
      final cat = _catalog[i];
      final installed = _installedRoms.firstWhere(
        (ins) => ins.filename == cat.filename,
        orElse: () => const ArcadeRomItem(id: '', name: '', filename: '', url: ''),
      );
      if (installed.filename.isNotEmpty) {
        _catalog[i] = cat.copyWith(
          isInstalled: true,
          localPath: installed.localPath,
          localSizeBytes: installed.localSizeBytes,
        );
      } else {
        _catalog[i] = cat.copyWith(
          isInstalled: false,
          localPath: null,
          localSizeBytes: null,
        );
      }
    }
  }
}
