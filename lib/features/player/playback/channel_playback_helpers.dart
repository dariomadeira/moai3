import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/plugin_host_service.dart';

/// Resultado final listo para el motor: URL + cabeceras + hint de formato
/// + config DRM (si la resolución la aporta).
class ResolvedPlayback {
  final String url;
  final Map<String, String> headers;
  final String? mimeType;
  final String? drmScheme;
  final String? drmLicenseUri;

  const ResolvedPlayback({
    required this.url,
    required this.headers,
    this.mimeType,
    this.drmScheme,
    this.drmLicenseUri,
  });
}

class ChannelPlaybackHelpers {
  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static List<String> playableUrls(Channel channel) => channel.fallbackUrls;

  /// Fuentes que se pueden probar: un canal-plugin siempre vale 1
  /// (cada intento re-resuelve en el plugin).
  static int playableUrlCount(Channel channel) =>
      channel.isPluginChannel ? 1 : channel.fallbackUrls.length;

  static String currentUrl(Channel channel, int fallbackIndex) {
    final urls = playableUrls(channel);
    if (fallbackIndex >= 0 && fallbackIndex < urls.length) {
      return urls[fallbackIndex];
    }
    return channel.url;
  }

  static const int _codeNetworkFailure = 1002;
  static const int _codeNetworkTimeout = 2002;
  static const int _codeBadHttpStatus = 2004;
  static const int _codeCleartextNotPermitted = 2007;

  static String friendlyPlaybackError(int? code, String? message) {
    final m = (message ?? '').trim().toLowerCase();
    if (m.contains('geo') ||
        m.contains('geo fencing') ||
        m.contains('geoblock') ||
        m.contains('geo-block')) {
      return 'playback_error_geo'.tr();
    }
    if (m.contains('closed_access') || m.contains('closed access')) {
      return 'playback_error_closed_access'.tr();
    }
    if (m.contains('401') ||
        m.contains('403') ||
        m.contains('unauthorized') ||
        m.contains('forbidden')) {
      return 'playback_error_http_auth'.tr();
    }
    if (m.contains('drm')) {
      return 'playback_error_drm'.tr();
    }
    if (code == _codeBadHttpStatus) {
      return 'playback_error_bad_http_status'.tr();
    }
    if (code == _codeCleartextNotPermitted) {
      return 'playback_error_cleartext'.tr();
    }
    if (code == _codeNetworkTimeout) return 'playback_error_timeout'.tr();
    if (code == _codeNetworkFailure) return 'playback_error_network'.tr();
    if (m.isNotEmpty) {
      return m.length > 90 ? '${m.substring(0, 87)}…' : m;
    }
    return code == null
        ? 'playback_error_unknown'.tr()
        : 'playback_error_code'.tr(namedArgs: {'code': '$code'});
  }

  static String shortUrlLabel(String url) {
    if (url.isEmpty) return '(vacía)';
    try {
      final uri = Uri.parse(url);
      final cleanUrl = url.split('?')[0];
      final cleanUri = Uri.parse(cleanUrl);
      final file =
          cleanUri.pathSegments.isNotEmpty ? cleanUri.pathSegments.last : '';
      final playerParam = uri.queryParameters['player'];
      final suffix = playerParam != null ? ' (P$playerParam)' : '';
      if (file.isNotEmpty) return '${cleanUri.host}/$file$suffix';
      return '${cleanUri.host}$suffix';
    } catch (_) {
      return url.length > 60 ? '${url.substring(0, 57)}…' : url;
    }
  }

  static String playbackSourceLabel(Channel channel, int fallbackIndex) {
    if (channel.isPluginChannel) {
      return 'Plugin · ${channel.pluginName ?? channel.pluginId ?? '?'}';
    }
    final url = currentUrl(channel, fallbackIndex);
    return 'Moai Server · ${shortUrlLabel(url)}';
  }

  /// Resuelve a lo que el motor debe reproducir.
  /// - Canales-plugin: sí al plugin (resolución viva, puede ser lenta).
  /// - Canales estáticos: URL directa + cabeceras del canal.
  static Future<ResolvedPlayback> resolvePlayback(
    Channel channel,
    int fallbackIndex, {
    PluginHostService? service,
  }) async {
    if (channel.isPluginChannel) {
      if (service == null) {
        throw StateError('Canal-plugin sin PluginHostService');
      }
      final resolved = await service.resolve(
        channel.pluginId!,
        channel.pluginChannelId!,
      );
      if (resolved.url.isEmpty) {
        throw Exception('El plugin no devolvió URL para ${channel.name}');
      }
      return ResolvedPlayback(
        url: resolved.url,
        headers: buildStreamHeaders(
          finalUrl: resolved.url,
          channel: channel,
          resolvedHeaders: resolved.headers,
        ),
        mimeType: resolved.mimeType,
        drmScheme: resolved.drmScheme,
        drmLicenseUri: resolved.drmLicenceUrl,
      );
    }
    final url = currentUrl(channel, fallbackIndex);
    return ResolvedPlayback(
      url: url,
      headers: buildStreamHeaders(finalUrl: url, channel: channel),
      mimeType: mimeTypeHint(url),
    );
  }

  static void invalidateCache(String url) {}

  static String? mimeTypeHint(String url) {
    if (url.contains('.m3u8')) return 'application/x-mpegURL';
    if (url.contains('.mpd')) return 'application/dash+xml';
    return null;
  }

  static Map<String, String> buildStreamHeaders({
    required String finalUrl,
    required Channel channel,
    Map<String, String> resolvedHeaders = const {},
  }) {
    final custom = channel.customHeaders;
    return <String, String>{
      'User-Agent': defaultUserAgent,
      'Accept': '*/*',
      ...?custom,
      ...resolvedHeaders,
    };
  }
}

