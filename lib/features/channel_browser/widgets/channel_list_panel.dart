import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_grid.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel Canales: grilla por ventana de 2 columnas, con el encabezado de
/// Grupos y Categorías y tantas filas como entren enteras en el alto.
class ChannelListPanel extends StatefulWidget {
  final String selectedCountry;
  final String selectedCategory;
  final List<Channel> channels;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onSelect;
  final VoidCallback onLongPress;
  final VoidCallback? onFocusUp;

  /// Id del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedChannelId;

  const ChannelListPanel({
    super.key,
    required this.selectedCountry,
    required this.selectedCategory,
    required this.channels,
    required this.selectedChannel,
    required this.onSelect,
    required this.onLongPress,
    this.onFocusUp,
    this.tunedChannelId,
  });

  @override
  State<ChannelListPanel> createState() => ChannelListPanelState();
}

class ChannelListPanelState extends State<ChannelListPanel>
    implements FocusSelectable {
  late final _focus = FocusRequester(isMounted: () => mounted);
  static const int _crossAxisCount = 2;

  /// Alto mínimo de cada fila: la ficha con la placa del logo y el nombre
  /// (unos 96) más la separación.
  static const double _minRowExtent = 96 + ChannelGridTile.gap;

  final _listKey = GlobalKey<TvWindowedGridState<Channel>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'channel_empty');
  int? _focusedIndex;

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_focusedIndex != null && _focusedIndex! < widget.channels.length) {
      return _focusedIndex!;
    }
    final id = widget.selectedChannel?.id;
    if (id == null) return 0;
    final idx = widget.channels.indexWhere((c) => c.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

  @override
  void focusSelected() {
    if (widget.channels.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.channels.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant ChannelListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged =
        oldWidget.selectedChannel?.id != widget.selectedChannel?.id;
    final listChanged =
        !identical(oldWidget.channels, widget.channels) ||
        oldWidget.channels.length != widget.channels.length;
    if (selChanged || listChanged) {
      _focusedIndex = null;
    }
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
    final category = widget.selectedCategory.trim();
    return Container(
      padding: TvPanelSlots.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: category.isEmpty
                ? LocaleKeys.browser_channels_showing.tr()
                : LocaleKeys.browser_channels_title.tr(args: [category]),
            subtitle: widget.channels.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : LocaleKeys.browser_channels_showing.tr(),
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: widget.channels.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: TvEmptyStateCard(
                      focusNode: _emptyFocusNode,
                      icon: MoaiIcons.tvChannelsEmpty,
                      message: LocaleKeys.browser_channels_empty.tr(),
                      onFocusUp: widget.onFocusUp,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Entran tantas filas como quepan enteras y se
                      // estiran para llenar el alto (como en Grupos).
                      final height = constraints.maxHeight;
                      final rows = (height / _minRowExtent).floor().clamp(
                        1,
                        32,
                      );
                      return TvWindowedGrid<Channel>(
                        key: _listKey,
                        items: widget.channels,
                        windowSize: rows * _crossAxisCount,
                        itemExtent: height / rows,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        onFocusUpFromFirst: widget.onFocusUp,
                        onFocusedGlobalIndex: (idx) {
                          _focusedIndex = idx;
                        },
                        itemBuilder:
                            (
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
                                isSelected: widget.tunedChannelId == channel.id,
                                focusNode: focusNode,
                                onLongPress: widget.onLongPress,
                                onKeyUp: onKeyUp,
                                onKeyDown: onKeyDown,
                                onKeyLeft: onKeyLeft,
                                onKeyRight: onKeyRight,
                                onTap: () => widget.onSelect(channel),
                              );
                            },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
