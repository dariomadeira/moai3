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

  final AppPreferences _prefs;
  late final ChannelRepository _channelRepository;
  late final PlaybackSignals _playbackSignals;
  late final PluginHostController _pluginHost;

  Channel? _selectedChannel;

  ChannelProvider(this._prefs) {
    _channelRepository = ChannelRepository(_prefs);
    _playbackSignals = PlaybackSignals();
    _pluginHost = PluginHostController();

    _channelRepository.addListener(notifyListeners);
    _playbackSignals.addListener(notifyListeners);
    _pluginHost.addListener(_syncPluginChannels);

    unawaited(_bootstrap());
  }

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

    if (matchedChannel != null) {
      _selectedChannel = matchedChannel;
      return;
    }

    // Mientras las fuentes estén cargando en segundo plano, mantenemos la
    // preferencia intacta en _prefs a la espera de la lista completa.
    if (_pluginHost.loading) {
      return;
    }

    // Si hubo un error al cargar una fuente pero existen otros canales,
    // se asigna un canal en memoria sin borrar la preferencia guardada.
    if (_pluginHost.error != null && channels.isNotEmpty) {
      _selectedChannel = channels.first;
      _playbackSignals.bumpReload();
      _playbackSignals.setChannelError(false);
      return;
    }

    // Si la carga finalizó limpiamente y el canal ya no existe (ej: fuente desinstalada):
    if (channels.isNotEmpty) {
      _selectedChannel = channels.first;
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
    _validateSelectedChannel();
  }

  void selectChannel(Channel channel) {
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
