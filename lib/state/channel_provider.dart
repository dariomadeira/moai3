import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moai3/data/repositories/channel_repository.dart';
import 'package:moai3/data/repositories/playback_signals.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/plugin_host_service.dart';

/// Provider responsable del catálogo de canales, selección activa, grupos,
/// señales de reproducción y gestión de plugins.
class ChannelProvider extends ChangeNotifier {
  static const String _selectedChannelIdKey = 'selected_channel_id';
  static const String _lastSafeChannelIdKey = 'last_safe_channel_id';

  final AppPreferences _prefs;
  final bool Function()? _isAdultUnlocked;
  late final ChannelRepository _channelRepository;
  late final PlaybackSignals _playbackSignals;
  late final PluginHostController _pluginHost;

  Channel? _selectedChannel;
  Channel? _lastNonAdultChannel;

  ChannelProvider(this._prefs, {this._isAdultUnlocked}) {
    _channelRepository = ChannelRepository(_prefs);
    _playbackSignals = PlaybackSignals();
    _pluginHost = PluginHostController();

    _channelRepository.addListener(notifyListeners);
    _playbackSignals.addListener(notifyListeners);
    _pluginHost.addListener(_syncPluginChannels);

    unawaited(_bootstrap());
  }

  bool get isAdultUnlocked => _isAdultUnlocked?.call() ?? false;

  Future<void> _bootstrap() async {
    await _pluginHost.refresh();
    _loadPersistedSelection();
    notifyListeners();
  }

  void _syncPluginChannels() {
    _channelRepository.setPluginChannels(_pluginHost.channels);
    _validateSelectedChannel();
    notifyListeners();
  }

  List<Channel> get allChannels => _channelRepository.channels;
  List<ChannelGroup> get groups => _channelRepository.groups;
  bool get isLoadingChannels => _channelRepository.isLoading;
  String? get channelLoadError => _channelRepository.loadError;
  String? get streamEngine => _channelRepository.streamEngine;
  bool get isPuppeteerEngine => streamEngine == 'puppeteer';
  Channel? get selectedChannel => _selectedChannel;

  PluginHostController get pluginHost => _pluginHost;

  Channel? _findSafeFallbackChannel(List<Channel> channels) {
    final adultUnlocked = isAdultUnlocked;

    // 1. Último canal no adulto en memoria
    if (_lastNonAdultChannel != null) {
      if (channels.isEmpty) {
        return _lastNonAdultChannel;
      }
      final matched = channels.where((c) => c.id == _lastNonAdultChannel!.id).firstOrNull;
      if (matched != null) return matched;
    }

    if (channels.isEmpty) return null;

    // 2. Último canal seguro guardado en preferencias
    final savedSafeId = _prefs.readOptionalString(_lastSafeChannelIdKey);
    if (savedSafeId != null) {
      final candidate = channels.where((c) => c.id == savedSafeId).firstOrNull;
      if (candidate != null && (!candidate.isAdult || adultUnlocked)) {
        return candidate;
      }
    }

    // 3. Canal inicial sugerido por los plugins instalados
    for (final source in _pluginHost.sources) {
      final initId = source.initialChannel;
      if (initId != null && initId.isNotEmpty) {
        final candidate = channels.where((c) {
          return c.pluginChannelId == initId ||
              c.id == initId ||
              c.id.endsWith(':$initId');
        }).firstOrNull;
        if (candidate != null && (!candidate.isAdult || adultUnlocked)) {
          return candidate;
        }
      }
    }

    // 4. Primer canal NO adulto disponible
    final firstNonAdult = channels.where((c) => !c.isAdult).firstOrNull;
    if (firstNonAdult != null) return firstNonAdult;

    // 5. Si todos los canales son adultos, solo seleccionable si adultos está desbloqueado
    if (adultUnlocked) return channels.first;

    return null;
  }

  void _validateSelectedChannel() {
    final channels = _channelRepository.channels;
    final savedChannelId =
        _prefs.readOptionalString(_selectedChannelIdKey) ?? _selectedChannel?.id;

    Channel? matchedChannel;
    if (savedChannelId != null) {
      try {
        matchedChannel = channels.firstWhere((c) => c.id == savedChannelId);
      } catch (_) {
        matchedChannel = null;
      }
    }

    // Si el canal guardado es para adultos pero el control parental está activo/bloqueado,
    // no se permite seleccionarlo para esta sesión protegida.
    if (matchedChannel != null && matchedChannel.isAdult && !isAdultUnlocked) {
      matchedChannel = null;
    }

    if (matchedChannel != null) {
      _selectedChannel = matchedChannel;
      if (!matchedChannel.isAdult) {
        _lastNonAdultChannel = matchedChannel;
      }
      return;
    }

    // Mientras las fuentes estén cargando en segundo plano, mantenemos la
    // preferencia intacta en _prefs a la espera de la lista completa.
    if (_pluginHost.loading) {
      return;
    }

    final fallback = _findSafeFallbackChannel(channels);

    // Si hubo un error al cargar una fuente pero existen otros canales,
    // se asigna un canal en memoria sin borrar la preferencia guardada.
    if (_pluginHost.error != null && fallback != null) {
      _selectedChannel = fallback;
      if (!fallback.isAdult) {
        _lastNonAdultChannel = fallback;
      }
      _playbackSignals.bumpReload();
      _playbackSignals.setChannelError(false);
      return;
    }

    // Si la carga finalizó limpiamente:
    if (fallback != null) {
      _selectedChannel = fallback;
      if (!fallback.isAdult) {
        _lastNonAdultChannel = fallback;
      }
      _prefs.saveString(_selectedChannelIdKey, _selectedChannel!.id);
      _playbackSignals.bumpReload();
      _playbackSignals.setChannelError(false);
    } else {
      _selectedChannel = null;
      _prefs.removePreference(_selectedChannelIdKey);
      _playbackSignals.bumpReload();
      _playbackSignals.setChannelError(false);
    }
  }

  void _loadPersistedSelection() {
    final savedSafeId = _prefs.readOptionalString(_lastSafeChannelIdKey);
    if (savedSafeId != null) {
      _lastNonAdultChannel = _channelRepository.channels
          .where((c) => c.id == savedSafeId && !c.isAdult)
          .firstOrNull;
    }
    _validateSelectedChannel();
  }

  void selectChannel(Channel channel) {
    if (!channel.isAdult) {
      _lastNonAdultChannel = channel;
      _prefs.saveString(_lastSafeChannelIdKey, channel.id);
    }
    if (_selectedChannel?.id == channel.id) {
      if (_playbackSignals.currentChannelHasError) {
        _playbackSignals.bumpReload();
      }
      return;
    }
    _selectedChannel = channel;
    _playbackSignals.bumpReload();
    _playbackSignals.setChannelError(false);
    _prefs.saveString(_selectedChannelIdKey, channel.id);
    notifyListeners();
  }

  /// Invocado cuando el control parental se bloquea. Si el canal activo actual
  /// es de adultos, se cambia de inmediato al último canal seguro o al primer
  /// canal no adulto del catálogo.
  void onAdultLocked() {
    if (_selectedChannel != null && _selectedChannel!.isAdult) {
      final fallback = _findSafeFallbackChannel(_channelRepository.channels);
      if (fallback != null) {
        selectChannel(fallback);
      } else {
        _selectedChannel = null;
        _prefs.removePreference(_selectedChannelIdKey);
        _playbackSignals.bumpReload();
        _playbackSignals.setChannelError(false);
        notifyListeners();
      }
    }
  }

  int get serverSkipKey => _playbackSignals.serverSkipKey;
  int get reloadKey => _playbackSignals.reloadKey;
  bool get currentChannelHasError => _playbackSignals.currentChannelHasError;

  void skipServer() => _playbackSignals.skipServer();
  void bumpReload() => _playbackSignals.bumpReload();
  void setChannelError(bool hasError) =>
      _playbackSignals.setChannelError(hasError);

  Future<void> createGroup(String name,
      [List<String> channelIds = const []]) async {
    await _channelRepository.createGroup(name, channelIds);
    notifyListeners();
  }

  Future<void> deleteGroup(String id) async {
    await _channelRepository.deleteGroup(id);
    notifyListeners();
  }

  @override
  void dispose() {
    _channelRepository.removeListener(notifyListeners);
    _playbackSignals.removeListener(notifyListeners);
    _pluginHost.removeListener(_syncPluginChannels);
    _channelRepository.dispose();
    _playbackSignals.dispose();
    _pluginHost.dispose();
    super.dispose();
  }
}
