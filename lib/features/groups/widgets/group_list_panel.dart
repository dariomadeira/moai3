import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/widgets/cards/group_card.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Panel Grupos: mismo diseño windowed de 6 que Países / Categorías.
class GroupListPanel extends StatefulWidget {
  final List<ChannelGroup> groups;
  final ChannelGroup? selectedGroup;
  final ValueChanged<ChannelGroup> onSelect;
  final ValueChanged<ChannelGroup>? onLongPress;
  final VoidCallback? onFocusUp;

  const GroupListPanel({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onSelect,
    this.onLongPress,
    this.onFocusUp,
  });

  @override
  State<GroupListPanel> createState() => GroupListPanelState();
}

class GroupListPanelState extends State<GroupListPanel> {
  final _listKey = GlobalKey<TvWindowedListState<ChannelGroup>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'group_empty');

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final id = widget.selectedGroup?.id;
    if (id == null) return 0;
    final idx = widget.groups.indexWhere((g) => g.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

  void focusSelected() {
    if (widget.groups.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.groups.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant GroupListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged = oldWidget.selectedGroup?.id != widget.selectedGroup?.id;
    final listChanged = !identical(oldWidget.groups, widget.groups) ||
        oldWidget.groups.length != widget.groups.length;
    if ((selChanged || listChanged) && widget.groups.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _listKey.currentState?.ensureVisible(
          _selectedIndex,
          requestFocus: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const windowSize = 6;
    final listAlign = widget.groups.length < windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return Container(
      padding: const EdgeInsets.only(
        left: 4,
        right: 12,
        top: 8,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelListHeader(
            subtitle: 'groups_list_subtitle'.tr(),
            showFilterText: widget.groups.length > 1,
          ),
          Expanded(
            child: widget.groups.isEmpty
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: Icons.search_rounded,
                    message: 'browser_groups_empty'.tr(),
                    onFocusUp: widget.onFocusUp,
                  )
                : Align(
                    alignment: listAlign,
                    child: TvWindowedList<ChannelGroup>(
                      key: _listKey,
                      items: widget.groups,
                      windowSize: windowSize,
                      initialGlobalIndex: _selectedIndex,
                      itemExtent: TvLayoutConstants.categoryItemHeight,
                      onFocusUpFromFirst: widget.onFocusUp,
                      itemBuilder: (
                        context,
                        group,
                        focusNode,
                        local,
                        global,
                        onKeyUp,
                        onKeyDown,
                      ) {
                        return GroupCard(
                          key: ValueKey('group-${group.id}'),
                          groupName: group.name,
                          iconKey: group.icon,
                          isSelected: widget.selectedGroup?.id == group.id,
                          focusNode: focusNode,
                          onLongPress: () => widget.onLongPress?.call(group),
                          onKeyUp: onKeyUp,
                          onKeyDown: onKeyDown,
                          onTap: () => widget.onSelect(group),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

