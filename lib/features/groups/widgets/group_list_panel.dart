import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel Marcadores: el mismo diseño que Grupos y Categorías (encabezado con
/// degradado, fichas que llenan el alto y los estados del rail en verde de
/// TV).
class GroupListPanel extends StatefulWidget {
  final List<ChannelGroup> groups;
  final ChannelGroup? selectedGroup;
  final ValueChanged<ChannelGroup> onSelect;
  final ValueChanged<ChannelGroup>? onLongPress;
  final VoidCallback? onFocusUp;

  /// Id del canal sintonizado (el del visor): llevan el check los marcadores
  /// que lo contienen, no el que se va eligiendo al navegar.
  final String? tunedChannelId;

  const GroupListPanel({
    super.key,
    required this.groups,
    required this.selectedGroup,
    required this.onSelect,
    this.onLongPress,
    this.onFocusUp,
    this.tunedChannelId,
  });

  @override
  State<GroupListPanel> createState() => GroupListPanelState();
}

class GroupListPanelState extends State<GroupListPanel>
    implements FocusSelectable {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _listKey = GlobalKey<TvWindowedListState<ChannelGroup>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'group_empty');
  int? _focusedIndex;

  /// Alto mínimo de cada lugar: ficha de 48 más la separación.
  static const double _minItemExtent = 48 + TvPanelSlots.gap;

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_focusedIndex != null && _focusedIndex! < widget.groups.length) {
      return _focusedIndex!;
    }
    final id = widget.selectedGroup?.id;
    if (id == null) return 0;
    final idx = widget.groups.indexWhere((g) => g.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

  /// Lo llama HomeTvArea (rail → / ← desde canales / alfabeto).
  @override
  void focusSelected() {
    if (widget.groups.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusGlobalIndex(int index) {
    if (widget.groups.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant GroupListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged = oldWidget.selectedGroup?.id != widget.selectedGroup?.id;
    if (selChanged) {
      _focusedIndex = null;
    }
    if (selChanged && widget.groups.isNotEmpty) {
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
      padding: TvPanelSlots.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: LocaleKeys.groups_list_title.tr(),
            subtitle: widget.groups.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : LocaleKeys.groups_list_subtitle.tr(),
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: widget.groups.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: TvEmptyStateCard(
                      focusNode: _emptyFocusNode,
                      icon: MoaiIcons.tvTabMarcadores,
                      message: LocaleKeys.browser_groups_empty.tr(),
                      onFocusUp: widget.onFocusUp,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Entran tantas fichas como quepan enteras y se
                      // estiran para llenar el alto (como en Grupos).
                      final height = constraints.maxHeight;
                      final windowSize = (height / _minItemExtent)
                          .floor()
                          .clamp(1, 64);
                      final itemExtent = height / windowSize;
                      return TvWindowedList<ChannelGroup>(
                        key: _listKey,
                        items: widget.groups,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        onFocusUpFromFirst: widget.onFocusUp,
                        onFocusedGlobalIndex: (idx) {
                          _focusedIndex = idx;
                        },
                        itemBuilder:
                            (
                              context,
                              group,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: TvPanelSlots.gap / 2,
                                ),
                                child: TvGroupTile(
                                  key: ValueKey('group-${group.id}'),
                                  label: group.name,
                                  icon: MoaiIcons.groupIconFor(group.icon),
                                  isSelected: group.channelIds.contains(
                                    widget.tunedChannelId,
                                  ),
                                  focusNode: focusNode,
                                  onLongPress: () =>
                                      widget.onLongPress?.call(group),
                                  onKeyUp: onKeyUp,
                                  onKeyDown: onKeyDown,
                                  onTap: () => widget.onSelect(group),
                                ),
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
