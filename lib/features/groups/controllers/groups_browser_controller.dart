import 'package:flutter/material.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class GroupsBrowserController extends ChangeNotifier with SafeChangeNotifier {
  List<ChannelGroup> groups = [];
  ChannelGroup? selectedGroup;
  Channel? selectedChannel;

  List<Channel> filteredChannels = [];

  final List<FocusNode> groupFocusNodes = [];
  final List<FocusNode> channelFocusNodes = [];

  ChannelGroup? alphabetModeGroup;
  List<String> alphabetLetters = [];
  final List<FocusNode> alphabetFocusNodes = [];

  bool get isAlphabetMode => alphabetModeGroup != null;
  bool get canDeleteAlphabetGroup =>
      alphabetModeGroup != null && alphabetModeGroup!.isDeletable;

  final ScrollController groupScrollController = ScrollController();
  final ScrollController channelScrollController = ScrollController();

  bool activateAlphabetMode(ChannelGroup group) {
    alphabetModeGroup = group;
    alphabetLetters = groups
        .map((g) => g.name.isNotEmpty ? g.name[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final count =
        canDeleteAlphabetGroup ? alphabetLetters.length + 1 : alphabetLetters.length;
    FocusScrollSync.syncFocusNodes(count, alphabetFocusNodes);
    safeNotifyListeners();

    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (alphabetFocusNodes.isNotEmpty) {
          alphabetFocusNodes[0].requestFocus();
        }
      });
    } catch (_) {}
    return true;
  }

  void clearAlphabetMode() {
    alphabetModeGroup = null;
    safeNotifyListeners();
  }

  void jumpToLetter(
      String letter, List<Channel> allChannels, List<String> favoriteChannelIds) {
    alphabetModeGroup = null;
    safeNotifyListeners();

    final targetIdx = groups.indexWhere(
      (g) =>
          g.name.isNotEmpty &&
          g.name.toUpperCase().startsWith(letter.toUpperCase()),
    );

    if (targetIdx != -1) {
      // El panel windowed recentra vía selectedGroup + focusSelected() en Home.
      selectGroup(groups[targetIdx], allChannels, favoriteChannelIds);
    }
  }

  void syncFrom(List<ChannelGroup> serverGroups, List<Channel> allChannels,
      List<String> favoriteChannelIds) {
    groups = serverGroups;
    FocusScrollSync.syncFocusNodes(groups.length, groupFocusNodes);

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

  void focusSelectedGroup() {
    if (selectedGroup == null && groups.isNotEmpty) {
      selectedGroup = groups.first;
    }
    var idx = groups.indexWhere((g) => g.id == selectedGroup?.id);
    if (idx == -1 && groups.isNotEmpty) idx = 0;
    if (idx == -1) return;
    FocusScrollSync.focusListItem(
      scrollController: groupScrollController,
      focusNodes: groupFocusNodes,
      index: idx,
      itemHeight: TvLayoutConstants.categoryItemHeight,
      itemCount: groups.length,
    );
  }

  void focusSelectedChannel() {
    if (selectedChannel == null && filteredChannels.isNotEmpty) {
      selectedChannel = filteredChannels.first;
    }
    var idx = filteredChannels.indexWhere((c) => c.id == selectedChannel?.id);
    if (idx == -1 && filteredChannels.isNotEmpty) idx = 0;
    if (idx == -1) return;
    FocusScrollSync.focusListItem(
      scrollController: channelScrollController,
      focusNodes: channelFocusNodes,
      index: idx,
      itemHeight: TvLayoutConstants.channelItemHeight,
      itemCount: filteredChannels.length,
    );
  }

  void _refreshFilteredChannels(
      List<Channel> allChannels, List<String> favoriteChannelIds) {
    if (selectedGroup == null) {
      filteredChannels = [];
      FocusScrollSync.syncFocusNodes(0, channelFocusNodes);
      return;
    }

    if (selectedGroup!.type == 'favorites') {
      filteredChannels =
          allChannels.where((c) => favoriteChannelIds.contains(c.id)).toList();
    } else {
      final allowedIds = selectedGroup!.channelIds.toSet();
      filteredChannels =
          allChannels.where((c) => allowedIds.contains(c.id)).toList();
    }

    filteredChannels
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    FocusScrollSync.syncFocusNodes(filteredChannels.length, channelFocusNodes);
  }

  @override
  void dispose() {
    groupScrollController.dispose();
    channelScrollController.dispose();
    for (final node in groupFocusNodes) {
      node.dispose();
    }
    for (final node in channelFocusNodes) {
      node.dispose();
    }
    for (final node in alphabetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

