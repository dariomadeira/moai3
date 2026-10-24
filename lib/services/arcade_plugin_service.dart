import 'dart:io';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Servicio singleton para gestionar la descarga, instalación y desinstalación
/// del plugin del motor nativo Arcade (FBNeo libfbneo.so).
class ArcadePluginService extends ChangeNotifier {
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

  late AppPreferences _prefs;

  Future<void> init(AppPreferences prefs) async {
    _prefs = prefs;
    await refresh();
  }

  /// Revalida que el core `.so` guardado siga en disco.
  Future<void> refresh() async {
    _installedCorePath = _prefs.readOptionalString(_keyCorePath);

    // Verificar si el archivo .so existe en disco
    if (_installedCorePath != null) {
      final file = File(_installedCorePath!);
      if (await file.exists()) {
        _isInstalled = true;
      } else {
        _isInstalled = false;
        _installedCorePath = null;
        await _prefs.removePreference(_keyCorePath);
      }
    } else {
      _isInstalled = false;
    }
    notifyListeners();
  }

  static String getDeviceAbi() {
    if (kIsWeb) return 'arm64-v8a';
    try {
      final v = Platform.version.toLowerCase();
      if (v.contains('arm64')) return 'arm64-v8a';
      if (v.contains('arm')) return 'armeabi-v7a';
      if (v.contains('x64') || v.contains('x86_64')) return 'x86_64';
      if (v.contains('ia32') || v.contains('x86')) return 'x86';
      return 'arm64-v8a';
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
    _statusMessage = LocaleKeys.plugins_arcade_downloading_engine.tr();
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
        throw HttpException(
          LocaleKeys.arcade_error_core_download.tr(
            namedArgs: {'code': '${response.statusCode}'},
          ),
        );
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

      await _prefs.saveString(_keyCorePath, _installedCorePath!);

      _statusMessage = LocaleKeys.plugins_arcade_installed_success.tr();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ArcadePluginService] Error instalando plugin: $e');
      _isDownloading = false;
      _statusMessage =
          LocaleKeys.plugins_arcade_error_download.tr(namedArgs: {'error': '$e'});
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
      _statusMessage = LocaleKeys.plugins_arcade_uninstalled_success.tr();

      await _prefs.removePreference(_keyCorePath);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ArcadePluginService] Error desinstalando plugin: $e');
      return false;
    }
  }
}
