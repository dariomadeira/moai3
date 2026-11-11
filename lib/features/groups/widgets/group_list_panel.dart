import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_group_list_panel.dart';

typedef GroupListPanelState = TvGroupListPanelState<ChannelGroup>;

/// Panel Marcadores: el mismo diseño que Grupos y Categorías.
class GroupListPanel extends TvGroupListPanel<ChannelGroup> {
  final List<ChannelGroup> groups;
  final ChannelGroup? selectedGroup;
  final ValueChanged<ChannelGroup> onSelect;
  final ValueChanged<ChannelGroup>? onLongPress;

  /// Id del canal sintonizado (el del visor): llevan el check los marcadores
  /// que lo contienen, no el que se va eligiendo al navegar.
  final String? tunedChannelId;

  const GroupListPanel({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onSelect,
    this.onLongPress,
    super.onFocusUp,
    this.tunedChannelId,
  });

  @override
  List<ChannelGroup> get items => groups;

  @override
  int get selectedIndex {
    final id = selectedGroup?.id;
    return id == null ? -1 : groups.indexWhere((g) => g.id == id);
  }

  @override
  bool selectionChanged(GroupListPanel old) =>
      old.selectedGroup?.id != selectedGroup?.id;

  @override
  String get title => LocaleKeys.groups_list_title.tr();

  @override
  String get subtitle => LocaleKeys.groups_list_subtitle.tr();

  @override
  IconData get emptyIcon => MoaiIcons.tvTabMarcadores;

  @override
  String get emptyMessage => LocaleKeys.browser_groups_empty.tr();

  @override
  String get debugName => 'group';

  @override
  Widget buildTile(
    BuildContext context,
    ChannelGroup group,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) => TvGroupTile(
    key: ValueKey('group-${group.id}'),
    label: group.name,
    icon: MoaiIcons.groupIconFor(group.icon),
    isSelected: group.channelIds.contains(tunedChannelId),
    focusNode: focusNode,
    onLongPress: () => onLongPress?.call(group),
    onKeyUp: onKeyUp,
    onKeyDown: onKeyDown,
    onTap: () => onSelect(group),
  );
}
