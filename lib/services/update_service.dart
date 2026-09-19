import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Información de una versión disponible para actualizar.
class AppUpdateInfo {
  final String version;
  final String apkUrl;
  final String changelog;
  final int? fileSize;
  final String? releaseTag;

  const AppUpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.changelog,
    this.fileSize,
    this.releaseTag,
  });

  String get formattedSize {
    if (fileSize == null || fileSize! <= 0) return '';
    final mb = fileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Servicio encargado de verificar, descargar e instalar actualizaciones OTA.
class UpdateService {
  static const MethodChannel _deviceChannel =
      MethodChannel('com.infomak.moai.tv/device');

  /// URL de consulta de versiones (por defecto GitHub Releases del repositorio de moai3).
  /// También soporta un endpoint JSON estándar.
  static String updateEndpoint =
      'https://api.github.com/repos/dariomadeira/moai3/releases/latest';

  /// Comprueba si existe una versión más reciente que la instalada localmente.
  static Future<AppUpdateInfo?> checkForUpdate({String? customEndpoint}) async {
    final endpoint = customEndpoint ?? updateEndpoint;
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);

      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0 MoaiTV');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[UpdateService] Error HTTP al consultar versión: ${response.statusCode}');
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final data = json.decode(responseBody);

      return await _parseUpdateData(data);
    } catch (e) {
      debugPrint('[UpdateService] Excepción al verificar actualización: $e');
      return null;
    }
  }

  static Future<AppUpdateInfo?> _parseUpdateData(dynamic data) async {
    if (data is! Map<String, dynamic>) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();

    String remoteVersion = '';
    String apkUrl = '';
    String changelog = '';
    int? size;
    String? releaseTag;

    // Caso 1: Estructura de GitHub Releases
    if (data.containsKey('tag_name')) {
      releaseTag = (data['tag_name'] as String? ?? '').trim();
      remoteVersion = releaseTag.replaceFirst(RegExp(r'^[vV]'), '').trim();
      changelog = (data['body'] as String? ?? '').trim();

      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String? ?? '';
          size = asset['size'] as int?;
          break;
        }
      }
    }
    // Caso 2: JSON personalizado simple (version, apkUrl, changelog)
    else if (data.containsKey('version')) {
      remoteVersion = (data['version'] as String? ?? '').trim();
      apkUrl = (data['apkUrl'] as String? ?? '').trim();
      changelog = (data['changelog'] as String? ?? '').trim();
      size = data['fileSize'] as int?;
    }

    if (remoteVersion.isEmpty || apkUrl.isEmpty) {
      return null;
    }

    if (_isNewer(currentVersion, remoteVersion)) {
      return AppUpdateInfo(
        version: remoteVersion,
        apkUrl: apkUrl,
        changelog: changelog.isNotEmpty ? changelog : 'Mejoras y correcciones generales.',
        fileSize: size,
        releaseTag: releaseTag,
      );
    }

    return null;
  }

  /// Compara versiones semánticas (ej: '3.0.8' vs '3.0.9').
  static bool _isNewer(String current, String remote) {
    try {
      final curParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = curParts.length > remParts.length ? curParts.length : remParts.length;
      while (curParts.length < maxLen) {
        curParts.add(0);
      }
      while (remParts.length < maxLen) {
        remParts.add(0);
      }

      for (var i = 0; i < maxLen; i++) {
        if (remParts[i] > curParts[i]) return true;
        if (remParts[i] < curParts[i]) return false;
      }
      return false;
    } catch (_) {
      return current != remote;
    }
  }

  /// Descarga el APK reportando el progreso de 0.0 a 1.0.
  /// Retorna la ruta absoluta del archivo APK descargado.
  static Future<String> downloadApk(
    String apkUrl, {
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);

    final request = await client.getUrl(Uri.parse(apkUrl));
    request.headers.set('User-Agent', 'Mozilla/5.0 MoaiTV');
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException('Error ${response.statusCode} al descargar APK');
    }

    final totalBytes = response.contentLength;
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/moai_update.apk';
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    final sink = file.openWrite();
    var received = 0;

    try {
      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          await sink.close();
          if (await file.exists()) await file.delete();
          throw Exception('Descarga cancelada');
        }

        sink.add(chunk);
        received += chunk.length;

        if (totalBytes > 0) {
          final progress = (received / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, received, totalBytes);
        } else {
          onProgress(-1.0, received, -1);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return filePath;
  }

  /// Envía el Intent al sistema operativo Android para lanzar la instalación.
  static Future<bool> installApk(String filePath) async {
    try {
      final success = await _deviceChannel.invokeMethod<bool>(
        'installApk',
        {'path': filePath},
      );
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('[UpdateService] Error al lanzar instalador de APK: $e');
      return false;
    }
  }
}
