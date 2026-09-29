import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/home/widgets/panel_list_header.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_fixed_window_viewport.dart';
import 'package:moai3/widgets/lists/tv_windowed_grid.dart';

/// Panel Canales: grilla windowed 2×3 con D-pad.
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
  static const int _windowSize = 6;
  static const int _crossAxisCount = 2;
  static const double _rowExtent = 114.0;
  static const int _rowCount = _windowSize ~/ _crossAxisCount;

  final _listKey = GlobalKey<TvWindowedGridState<Channel>>();
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
            subtitle: 'browser_channels_showing'.tr(),
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
                : TvFixedWindowViewport(
                    slotCount: _rowCount,
                    slotExtent: _rowExtent,
                    child: TvWindowedGrid<Channel>(
                      key: _listKey,
                      items: widget.channels,
                      windowSize: _windowSize,
                      crossAxisCount: _crossAxisCount,
                      initialGlobalIndex: _selectedIndex,
                      itemExtent: _rowExtent,
                      showScrollDots: true,
                      onFocusUpFromFirst: widget.onFocusUp,
                      itemBuilder: (
                        context,
                        channel,
                        focusNode,
                        local,
                        global,
                        onKeyUp,
                        onKeyDown,
                        onKeyLeft,
                        onKeyRight,
                      ) {
                        return ChannelGridTile(
                          key: ValueKey(channel.id),
                          channel: channel,
                          isSelected: widget.selectedChannel?.id == channel.id,
                          focusNode: focusNode,
                          onLongPress: widget.onLongPress,
                          onKeyUp: onKeyUp,
                          onKeyDown: onKeyDown,
                          onKeyLeft: onKeyLeft,
                          onKeyRight: onKeyRight,
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
