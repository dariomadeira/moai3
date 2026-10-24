import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moai3/models/channel.dart';
import 'package:easy_localization/easy_localization.dart';

/// Canal de un plugin tal como lo declara su manifest.
class PluginChannelInfo {
  final String id;
  final String nombre;
  final String logo;
  final String categoria;
  final String pais;

  final String flag;

  const PluginChannelInfo({
    required this.id,
    required this.nombre,
    this.logo = '',
    this.categoria = '',
    this.pais = '',
    this.flag = '',
  });

  factory PluginChannelInfo.fromMap(Map<dynamic, dynamic> map) {
    return PluginChannelInfo(
      id: map['id'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      logo: map['logo'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      pais: map['pais'] as String? ?? '',
      flag: (map['flag'] as String? ?? '').trim(),
    );
  }
}

/// Fuente (`.dex`) instalada, según la reporta el loader.
class PluginSource {
  final String id;
  final String tag;
  final String nombre;
  final String version;
  final int minContrato;
  final int maxContrato;
  final String sourceUrl;
  final String? initialChannel;
  final List<PluginChannelInfo> canales;

  const PluginSource({
    required this.id,
    this.tag = '',
    required this.nombre,
    required this.version,
    required this.minContrato,
    required this.maxContrato,
    required this.sourceUrl,
    this.initialChannel,
    required this.canales,
  });

  factory PluginSource.fromMap(Map<dynamic, dynamic> map) {
    final id = map['id'] as String? ?? '';
    final rawTag = (map['tag'] as String? ?? '').trim();
    final tag = rawTag.isNotEmpty
        ? rawTag
        : (id.startsWith('moai_') ? id.substring(5) : '');
    final rawInitial = (map['canalInicial'] ?? map['initialChannel']) as String?;
    final initial = (rawInitial != null && rawInitial.trim().isNotEmpty)
        ? rawInitial.trim()
        : null;
    return PluginSource(
      id: id,
      tag: tag,
      nombre: map['nombre'] as String? ?? '',
      version: map['version'] as String? ?? '',
      minContrato: map['minContrato'] as int? ?? 1,
      maxContrato: map['maxContrato'] as int? ?? 1,
      sourceUrl: map['sourceUrl'] as String? ?? '',
      initialChannel: initial,
      canales: ((map['canales'] as List?) ?? const [])
          .map((c) => PluginChannelInfo.fromMap(c as Map<dynamic, dynamic>))
          .toList(),
    );
  }
}

/// Resultado de [PluginHostService.resolve] — lo que reproduce el motor.
class PluginResolveResult {
  final String url;
  final Map<String, String> headers;
  final String? drmTipo;
  final String? drmLicenceUrl;

  /// "hls" | "dash" | "mpegts" | "directo".
  final String format;
  final int ttlMs;

  const PluginResolveResult({
    required this.url,
    this.headers = const {},
    this.drmTipo,
    this.drmLicenceUrl,
    this.format = 'directo',
    this.ttlMs = 0,
  });

  factory PluginResolveResult.fromMap(Map<dynamic, dynamic> map) {
    return PluginResolveResult(
      url: map['url'] as String? ?? '',
      headers: ((map['headers'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v.toString())),
      drmTipo: map['drmTipo'] as String?,
      drmLicenceUrl: map['drmLicenceUrl'] as String?,
      format: map['format'] as String? ?? 'directo',
      ttlMs: map['ttlMs'] as int? ?? 0,
    );
  }

  /// Hint de MIME para el motor (ExoPlayer lo deduce, esto acelera el parser).
  String? get mimeType {
    switch (format) {
      case 'hls':
        return 'application/x-mpegURL';
      case 'dash':
        return 'application/dash+xml';
      default:
        return null;
    }
  }

  String? get drmScheme =>
      drmTipo?.toUpperCase() == 'WIDEVINE' ? 'WIDEVINE' : drmTipo;
}

/// Cliente Dart del canal `com.infomak.moai.tv/plugin`.
class PluginHostService {
  static const MethodChannel _channel = PlatformChannels.plugin;

  Future<List<PluginSource>> list() async {
    final raw = await _channel.invokeListMethod<dynamic>('list') ?? const [];
    return raw
        .map((e) => PluginSource.fromMap(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<PluginSource> install(String url) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'install',
      {'url': url},
    );
    if (map == null) {
      throw PlatformException(
        code: 'PLUGIN_INSTALL_NULL',
        message: LocaleKeys.plugins_install_empty,
      );
    }
    return PluginSource.fromMap(map);
  }

  Future<PluginSource> updateSource(String url) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'update',
      {'url': url},
    );
    if (map == null) {
      throw PlatformException(
        code: 'PLUGIN_UPDATE_NULL',
        message: LocaleKeys.plugins_update_empty,
      );
    }
    return PluginSource.fromMap(map);
  }

  Future<void> remove(String id) async {
    await _channel.invokeMethod<void>('remove', {'id': id});
  }

  Future<PluginResolveResult> resolve(
    String pluginId,
    String channelId, {
    int fallbackIndex = 0,
  }) async {
    final map = await _channel.invokeMapMethod<dynamic, dynamic>(
      'resolve',
      {
        'pluginId': pluginId,
        'channelId': channelId,
        'fallbackIndex': fallbackIndex,
      },
    );
    if (map == null) {
      throw PlatformException(
        code: 'PLUGIN_RESOLVE_NULL',
        message: LocaleKeys.plugins_resolve_empty,
      );
    }
    return PluginResolveResult.fromMap(map);
  }
}

/// Estado de plugins instalados para la UI y el catálogo.
class PluginHostController extends ChangeNotifier {
  final PluginHostService _service;
  List<PluginSource> _sources = [];
  bool _loading = false;
  String? _error;
  Map<String, String> _errorNamedArgs = const {};
  bool _disposed = false;

  PluginHostController([PluginHostService? service])
      : _service = service ?? PluginHostService();

  List<PluginSource> get sources => List.unmodifiable(_sources);
  bool get loading => _loading;
  String? get error => _error;
  Map<String, String> get errorNamedArgs => _errorNamedArgs;

  /// Servicio subyacente (para resolución directa en playback).
  PluginHostService service() => _service;

  /// Canales consolidados de todos los plugins, para el catálogo.
  List<Channel> get channels =>
      PluginChannelCatalog.channelsFrom(_sources);

  Future<void> refresh() => _runOp(() async {
        _sources = await _service.list();
      });

  Future<void> install(String url) => _runOp(() async {
        await _service.install(url);
        _sources = await _service.list();
      });

  Future<void> updateSource(String url) => _runOp(() async {
        await _service.updateSource(url);
        _sources = await _service.list();
      });

  Future<void> removePlugin(String id) => _runOp(() async {
        await _service.remove(id);
        _sources = await _service.list();
      });

  Future<void> _runOp(Future<void> Function() op) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _errorNamedArgs = const {};
    _notify();
    try {
      await op();
    } catch (e) {
      _setError(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  void _setError(Object error) {
    if (error is PlatformException) {
      final message = error.message;
      if (message != null && message.startsWith('plugins_')) {
        _error = message;
        _errorNamedArgs = const {};
        return;
      }
    }
    _error = LocaleKeys.plugins_host_error;
    _errorNamedArgs = {'error': '$error'};
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Mapea canales de plugins al modelo [Channel] de la app.
class PluginChannelCatalog {
  static const String _prefix = 'plugin';

  /// Id global de la app para un canal de plugin (único entre fuentes).
  static String channelId(PluginSource source, PluginChannelInfo info) =>
      '$_prefix:${source.id}:${info.id}';

  static List<Channel> channelsFrom(List<PluginSource> sources) {
    final result = <Channel>[];
    for (final source in sources) {
      for (final info in source.canales) {
        result.add(
          Channel(
            id: channelId(source, info),
            name: info.nombre,
            logoUrl: info.logo,
            country: info.pais.trim().isEmpty ? LocaleKeys.browser_group_general.tr() : info.pais.trim(),
            category: info.categoria.trim().isEmpty ? LocaleKeys.browser_group_general.tr() : info.categoria.trim(),
            countryFlagUrl: info.flag.isNotEmpty ? info.flag : null,
            fallbackUrls: const [],
            pluginId: source.id,
            pluginChannelId: info.id,
            pluginName: source.nombre,
            pluginTag: source.tag.isNotEmpty ? source.tag : null,
          ),
        );
      }
    }
    return result;
  }
}