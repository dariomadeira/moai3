import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/home/widgets/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Panel Canales: mismo diseño windowed de 6 que Países / Categorías.
class ChannelListPanel extends StatefulWidget {
  final String selectedCountry;
  final String selectedCategory;
  final List<Channel> channels;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  const ChannelListPanel({
    super.key,
    required this.selectedCountry,
    required this.selectedCategory,
    required this.channels,
    required this.selectedChannel,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
  });

  @override
  State<ChannelListPanel> createState() => ChannelListPanelState();
}

class ChannelListPanelState extends State<ChannelListPanel> {
  final _listKey = GlobalKey<TvWindowedListState<Channel>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'channel_empty');

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    final id = widget.selectedChannel?.id;
    if (id == null) return 0;
    final idx = widget.channels.indexWhere((c) => c.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

  void focusSelected() {
    if (widget.channels.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.channels.isEmpty) {
      requestFocusWithRetry(_emptyFocusNode, isMounted: () => mounted);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant ChannelListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged =
        oldWidget.selectedChannel?.id != widget.selectedChannel?.id;
    final listChanged = !identical(oldWidget.channels, widget.channels) ||
        oldWidget.channels.length != widget.channels.length;
    if ((selChanged || listChanged) && widget.channels.isNotEmpty) {
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
    final listAlign = widget.channels.length < windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    final String target = widget.selectedCategory.isEmpty
        ? widget.selectedCountry
        : '${widget.selectedCountry} - ${widget.selectedCategory}';

    final String subtitle = target.isEmpty
        ? 'home_tv_viewer_no_channels'.tr()
        : 'browser_channels_showing'.tr(namedArgs: {'target': target});

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
            subtitle: subtitle,
            showFilterText: widget.channels.length > 1,
          ),
          Expanded(
            child: widget.channels.isEmpty
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: Symbols.hourglass_empty,
                    message: 'browser_channels_empty'.tr(),
                    onFocusUp: widget.onFocusUp,
                  )
                : Align(
                    alignment: listAlign,
                    child: TvWindowedList<Channel>(
                      key: _listKey,
                      items: widget.channels,
                      windowSize: windowSize,
                      initialGlobalIndex: _selectedIndex,
                      itemExtent: TvLayoutConstants.channelItemHeight,
                      onFocusUpFromFirst: widget.onFocusUp,
                      itemBuilder: (
                        context,
                        channel,
                        focusNode,
                        local,
                        global,
                        onKeyUp,
                        onKeyDown,
                      ) {
                        return NewChannelCard(
                          key: ValueKey(channel.id),
                          channel: channel,
                          isSelected: widget.selectedChannel?.id == channel.id,
                          focusNode: focusNode,
                          onLongPress: widget.onLongPress,
                          onKeyUp: onKeyUp,
                          onKeyDown: onKeyDown,
                          onTap: () => widget.onSelect(channel),
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

