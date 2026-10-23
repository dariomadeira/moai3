import 'package:flutter/material.dart';
import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class GroupsBrowserController extends ChangeNotifier with SafeChangeNotifier {
  List<ChannelGroup> groups = [];
  ChannelGroup? selectedGroup;
  Channel? selectedChannel;

  List<Channel> filteredChannels = [];

  ChannelGroup? alphabetModeGroup;
  /// `null` = off; `0` = alfabeto de grupos; `1` = alfabeto de canales.
  int? alphabetModePanelIndex;
  List<String> alphabetLetters = [];
  final List<FocusNode> alphabetFocusNodes = [];

  bool isAdultUnlocked = false;

  bool get isAlphabetMode => alphabetModePanelIndex != null;
  bool get canDeleteAlphabetGroup =>
      alphabetModePanelIndex == 0 &&
      alphabetModeGroup != null &&
      alphabetModeGroup!.isDeletable;

  bool activateAlphabetMode(ChannelGroup group) {
    alphabetModeGroup = group;
    alphabetModePanelIndex = 0;
    alphabetLetters = groups
        .map((g) => g.name.isNotEmpty ? g.name[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (alphabetLetters.isEmpty) {
      alphabetModeGroup = null;
      alphabetModePanelIndex = null;
      return false;
    }

    final count =
        canDeleteAlphabetGroup ? alphabetLetters.length + 1 : alphabetLetters.length;
    FocusScrollSync.syncFocusNodes(count, alphabetFocusNodes);
    safeNotifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (alphabetFocusNodes.isNotEmpty) {
        alphabetFocusNodes[0].requestFocus();
      }
    });
    return true;
  }

  /// Alfabeto sobre los canales del grupo seleccionado (panel Canales).
  bool activateChannelsAlphabetMode() {
    alphabetModeGroup = null;
    alphabetLetters = filteredChannels
        .map((c) => c.name.isNotEmpty ? c.name[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (alphabetLetters.isEmpty) return false;

    alphabetModePanelIndex = 1;
    FocusScrollSync.syncFocusNodes(alphabetLetters.length, alphabetFocusNodes);
    safeNotifyListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (alphabetFocusNodes.isNotEmpty) {
        alphabetFocusNodes[0].requestFocus();
      }
    });
    return true;
  }

  void clearAlphabetMode() {
    alphabetModeGroup = null;
    alphabetModePanelIndex = null;
    alphabetLetters = [];
    safeNotifyListeners();
  }

  /// Devuelve el índice del canal saltado, o `null` si era salto de grupos.
  int? jumpToLetter(
      String letter, List<Channel> allChannels, List<String> favoriteChannelIds) {
    final panel = alphabetModePanelIndex;
    alphabetModeGroup = null;
    alphabetModePanelIndex = null;
    safeNotifyListeners();

    if (panel == 1) {
      final idx = filteredChannels.indexWhere(
        (c) =>
            c.name.isNotEmpty &&
            c.name.toUpperCase().startsWith(letter.toUpperCase()),
      );
      if (idx < 0) return null;
      selectedChannel = filteredChannels[idx];
      safeNotifyListeners();
      return idx;
    }

    final targetIdx = groups.indexWhere(
      (g) =>
          g.name.isNotEmpty &&
          g.name.toUpperCase().startsWith(letter.toUpperCase()),
    );

    if (targetIdx != -1) {
      selectGroup(groups[targetIdx], allChannels, favoriteChannelIds);
    }
    return null;
  }

  void syncFrom(
    List<ChannelGroup> serverGroups,
    List<Channel> allChannels,
    List<String> favoriteChannelIds, {
    bool? isAdultUnlocked,
  }) {
    if (isAdultUnlocked != null) this.isAdultUnlocked = isAdultUnlocked;

    groups = this.isAdultUnlocked
        ? serverGroups
        : serverGroups
            .where((g) =>
                g.name.toLowerCase() != 'adultos' &&
                g.id.toLowerCase() != 'adultos')
            .toList();

    if (selectedGroup == null && groups.isNotEmpty) {
      selectedGroup = groups.first;
    } else if (selectedGroup != null) {
      final matching = groups.where((g) => g.id == selectedGroup!.id);
      selectedGroup = matching.isNotEmpty
          ? matching.first
          : (groups.isNotEmpty ? groups.first : null);
    }

    _refreshFilteredChannels(allChannels, favoriteChannelIds);
    safeNotifyListeners();
  }

  void selectGroup(ChannelGroup group, List<Channel> allChannels,
      List<String> favoriteChannelIds) {
    selectedGroup = group;
    _refreshFilteredChannels(allChannels, favoriteChannelIds);
    selectedChannel =
        filteredChannels.isNotEmpty ? filteredChannels.first : null;
    safeNotifyListeners();
  }

  void selectChannel(Channel channel) {
    selectedChannel = channel;
    safeNotifyListeners();
  }

  void _refreshFilteredChannels(
      List<Channel> allChannels, List<String> favoriteChannelIds) {
    if (selectedGroup == null) {
      filteredChannels = [];
      return;
    }

    final pool = isAdultUnlocked
        ? allChannels
        : allChannels
            .where((c) => !ChannelBrowserController.isAdult(c))
            .toList();

    if (selectedGroup!.type == 'favorites') {
      filteredChannels =
          pool.where((c) => favoriteChannelIds.contains(c.id)).toList();
    } else {
      final allowedIds = selectedGroup!.channelIds.toSet();
      filteredChannels =
          pool.where((c) => allowedIds.contains(c.id)).toList();
    }

    filteredChannels
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  void dispose() {
    for (final node in alphabetFocusNodes) {
      FocusScrollSync.disposeNode(node);
    }
    super.dispose();
  }
}

