import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class ChannelRepository extends ChangeNotifier with SafeChangeNotifier {
  static const String _customGroupsKey = 'custom_channel_groups';

  final AppPreferences? _prefs;

  List<Channel> _channels = [];
  List<ChannelGroup> _customGroups = [];
  List<ChannelGroup> _groups = [];
  bool _isLoading = false;
  String? _loadError;

  ChannelRepository([this._prefs]) {
    _loadCustomGroups();
  }

  List<Channel> get channels => _channels;
  List<ChannelGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  String? get streamEngine => null;

  void _loadCustomGroups() {
    if (_prefs == null) return;
    final savedStrings = _prefs.readStringList(_customGroupsKey);
    _customGroups = savedStrings.map((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return ChannelGroup.fromJson(map);
      } catch (_) {
        return null;
      }
    }).whereType<ChannelGroup>().toList();
    _rebuildGroups();
  }

  Future<void> _persistCustomGroups() async {
    if (_prefs == null) return;
    final encoded = _customGroups.map((g) => jsonEncode(g.toJson())).toList();
    await _prefs.saveStringList(_customGroupsKey, encoded);
  }

  void _rebuildGroups() {
    _groups = _customGroups
        .map((g) => ChannelGroup(
              id: g.id,
              name: g.name,
              icon: g.icon,
              type: g.type,
              channelIds: _channels.isEmpty
                  ? List.unmodifiable(g.channelIds)
                  : g.channelIds
                      .where((id) => _channels.any((c) => c.id == id))
                      .toList(),
            ))
        .toList();
    safeNotifyListeners();
  }

  /// Reemplaza el catálogo por los canales aportados por los plugins.
  void setPluginChannels(List<Channel> channels) {
    _channels = List.unmodifiable(channels);
    _loadError = null;
    _isLoading = false;
    _rebuildGroups();
  }

  Future<void> loadGroups() async {
    _loadCustomGroups();
  }

  Future<void> createGroup(
    String name, [
    List<String> channelIds = const [],
  ]) async {
    final newGroup = ChannelGroup(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: 'bookmark',
      type: 'custom',
      channelIds: channelIds,
    );
    _customGroups.add(newGroup);
    await _persistCustomGroups();
    _rebuildGroups();
  }

  Future<void> deleteGroup(String id) async {
    _customGroups.removeWhere((g) => g.id == id);
    await _persistCustomGroups();
    _rebuildGroups();
  }
}

