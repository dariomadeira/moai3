import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/services/plugin_host_service.dart';

/// Información de actualización de un plugin / fuente instalada.
class PluginUpdateInfo {
  final PluginSource source;
  final String remoteVersion;
  final int newChannelCount;
  final String manifestUrl;
  final String remoteSha256;

  const PluginUpdateInfo({
    required this.source,
    required this.remoteVersion,
    required this.newChannelCount,
    required this.manifestUrl,
    required this.remoteSha256,
  });
}

/// Servicio para verificar si existen nuevas versiones de las fuentes instaladas.
class PluginUpdateService {
  /// Obtiene la URL correspondiente al `manifest.json`.
  static String deriveManifestUrl(String rawUrl) {
    final clean = rawUrl.trim();
    if (clean.endsWith('manifest.json')) return clean;
    if (clean.endsWith('plugin.dex')) {
      return '${clean.substring(0, clean.length - 'plugin.dex'.length)}manifest.json';
    }
    // Si no termina en ninguno, asumir manifest.json
    return clean;
  }

  /// Comprueba si hay actualizaciones disponibles para una lista de fuentes.
  static Future<List<PluginUpdateInfo>> checkForUpdates(
    List<PluginSource> sources, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final updates = <PluginUpdateInfo>[];

    for (final source in sources) {
      if (source.sourceUrl.isEmpty) continue;

      try {
        final info = await checkSingleSource(source, timeout: timeout);
        if (info != null) {
          updates.add(info);
        }
      } catch (e) {
        debugPrint('[PluginUpdateService] Error al verificar ${source.nombre}: $e');
      }
    }

    return updates;
  }

  /// Comprueba una única fuente contra su manifiesto remoto.
  static Future<PluginUpdateInfo?> checkSingleSource(
    PluginSource source, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final manifestUrl = deriveManifestUrl(source.sourceUrl);
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null) return null;

    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0');
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint(
            '[PluginUpdateService] HTTP ${response.statusCode} al consultar $manifestUrl');
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = json.decode(body) as Map<String, dynamic>;

      final remoteVersion = (data['version'] as String? ?? '').trim();
      final remoteSha256 = (data['sha256'] as String? ?? '').trim();
      final canales = data['canales'] as List? ?? const [];

      if (remoteVersion.isEmpty) return null;

      if (isNewer(source.version, remoteVersion)) {
        return PluginUpdateInfo(
          source: source,
          remoteVersion: remoteVersion,
          newChannelCount: canales.length,
          manifestUrl: manifestUrl,
          remoteSha256: remoteSha256,
        );
      }
    } finally {
      client.close();
    }

    return null;
  }

  /// Compara versiones semánticas (ej: '1.3.2' vs '1.4.0').
  static bool isNewer(String current, String remote) {
    try {
      final curParts =
          current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remParts =
          remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = curParts.length > remParts.length
          ? curParts.length
          : remParts.length;
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
}
