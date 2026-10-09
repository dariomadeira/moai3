import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio singleton para gestionar la descarga, instalación y desinstalación
/// del plugin del motor nativo Arcade (FBNeo libfbneo.so).
class ArcadePluginService extends ChangeNotifier {
  static const String _keyInstalled = 'arcade_plugin_installed';
  static const String _keyCorePath = 'arcade_plugin_core_path';

  static const String baseUrl =
      'https://raw.githubusercontent.com/dariomadeira/moai_roms/main/cores';

  bool _isInstalled = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _installedCorePath;
  String _statusMessage = '';

  bool get isInstalled => _isInstalled;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get installedCorePath => _installedCorePath;
  String get statusMessage => _statusMessage;

  static final ArcadePluginService instance = ArcadePluginService._internal();
  ArcadePluginService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _installedCorePath = prefs.getString(_keyCorePath);

    // Verificar si el archivo .so existe en disco
    if (_installedCorePath != null) {
      final file = File(_installedCorePath!);
      if (await file.exists()) {
        _isInstalled = true;
      } else {
        _isInstalled = false;
        _installedCorePath = null;
        await prefs.setBool(_keyInstalled, false);
      }
    } else {
      _isInstalled = false;
    }
    notifyListeners();
  }

  static String getDeviceAbi() {
    try {
      final abi = Abi.current();
      switch (abi) {
        case Abi.androidArm64:
          return 'arm64-v8a';
        case Abi.androidArm:
          return 'armeabi-v7a';
        case Abi.androidX64:
          return 'x86_64';
        default:
          return 'arm64-v8a';
      }
    } catch (_) {
      return 'arm64-v8a';
    }
  }

  Future<bool> installPlugin({
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    if (_isDownloading) return false;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _statusMessage = 'Descargando motor Arcade...';
    notifyListeners();

    try {
      final abi = getDeviceAbi();
      final url = '$baseUrl/$abi/libfbneo.so';

      final appDir = await getApplicationDocumentsDirectory();
      final pluginsDir = Directory('${appDir.path}/plugins/arcade');
      if (!await pluginsDir.exists()) {
        await pluginsDir.create(recursive: true);
      }

      final targetFile = File('${pluginsDir.path}/libfbneo.so');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 MoaiTV');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} al descargar core');
      }

      final totalBytes = response.contentLength;
      var received = 0;
      final sink = targetFile.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = (received / totalBytes).clamp(0.0, 1.0);
          onProgress?.call(_downloadProgress, received, totalBytes);
        }
        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      client.close(force: true);

      _installedCorePath = targetFile.absolute.path;
      _isInstalled = true;
      _isDownloading = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyInstalled, true);
      await prefs.setString(_keyCorePath, _installedCorePath!);

      _statusMessage = 'Plugin instalado correctamente.';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ArcadePluginService] Error instalando plugin: $e');
      _isDownloading = false;
      _statusMessage = 'Error al descargar el plugin: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> uninstallPlugin() async {
    try {
      if (_installedCorePath != null) {
        final file = File(_installedCorePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _isInstalled = false;
      _installedCorePath = null;
      _downloadProgress = 0.0;
      _statusMessage = 'Plugin desinstalado.';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyInstalled, false);
      await prefs.remove(_keyCorePath);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ArcadePluginService] Error desinstalando plugin: $e');
      return false;
    }
  }
}
