part of '../home_tv_area.dart';

/// Pestaña Marcadores: grupos y sus canales.
extension _TvAreaGroups on HomeTvAreaState {
  Widget _buildGroupsAccordion(BuildContext context) {
    final scheme = context.scheme;
    final channelProv = context.read<ChannelProvider>();
    final favProv = context.read<FavoritesProvider>();
    const panelCount = 2;

    // Ancho final fijo: las listas no se re-layoutean mientras el acordeón
    // abre o cambia de panel.
    return TvAccordionRowPreview(
      panelCount: panelCount,
      fixedContentWidth: true,
      activeIndex: _groupsPanelIndex,
      colors: [
        scheme.surface.withValues(alpha: 0.8),
        scheme.surface.withValues(alpha: 0.8),
      ],
      titles: [
        LocaleKeys.home_panel_groups.tr(),
        LocaleKeys.home_panel_channels.tr(),
      ],
      icons: const [MoaiIcons.tvTabMarcadores, MoaiIcons.tvAccordionCanales],
      alphabetModePanelIndex: _groups.alphabetModePanelIndex,
      alphabetPanelBuilder: (_) => AlphabetJumpPanel(
        letters: _groups.alphabetLetters,
        focusNodes: _groups.alphabetFocusNodes,
        showDeleteTile: _groups.canDeleteAlphabetGroup,
        onDeleteTap: () async {
          final g = _groups.alphabetModeGroup;
          if (g == null) return;
          _groups.clearAlphabetMode();
          await channelProv.deleteGroup(g.id);
          if (!mounted) return;
          _groups.syncFrom(
            channelProv.groups,
            channelProv.allChannels,
            favProv.favoriteChannelIds,
            isAdultUnlocked: _lastIsAdultUnlocked,
          );
          _update(() {});
        },
        onLetterTap: (letter) {
          final channelIdx = _groups.jumpToLetter(
            letter,
            channelProv.allChannels,
            favProv.favoriteChannelIds,
          );
          _update(() {});
          if (channelIdx != null) {
            _afterFrame(() {
              _groupsChannelPanelKey.currentState?.focusGlobalIndex(channelIdx);
            });
          } else {
            _focusSelectedGroup();
          }
        },
      ),
      onPanelTap: (i) {
        if (_groupsAlphabetActive) return;
        _update(() => _groupsPanelIndex = i);
        _focusGroupsPanel();
      },
      buildExpandedContent: (index, title) {
        final panelWidget = index == 0
            ? Actions(
                actions: {
                  DpadLeftIntent: CallbackAction<DpadLeftIntent>(
                    onInvoke: (_) {
                      if (_groupsAlphabetActive) return null;
                      widget.onExitLeft();
                      return null;
                    },
                  ),
                  DpadRightIntent: CallbackAction<DpadRightIntent>(
                    onInvoke: (_) {
                      if (_groupsAlphabetActive) return null;
                      _update(() => _groupsPanelIndex = 1);
                      _focusGroupsChannel();
                      return null;
                    },
                  ),
                },
                child: GroupListPanel(
                  key: _groupListPanelKey,
                  groups: _groups.groups,
                  selectedGroup: _groups.selectedGroup,
                  onSelect: _selectGroup,
                  onLongPress: (g) {
                    if (_groups.activateAlphabetMode(g)) {
                      _update(() {});
                      FocusScrollSync.requestFocusAtIndex(
                        _groups.alphabetFocusNodes,
                        0,
                      );
                    }
                  },
                  onFocusUp: _focusCurrentTab,
                ),
              )
            : Actions(
                actions: {
                  DpadLeftIntent: CallbackAction<DpadLeftIntent>(
                    onInvoke: (_) {
                      if (_groupsAlphabetActive) return null;
                      _update(() => _groupsPanelIndex = 0);
                      _focusSelectedGroup();
                      return null;
                    },
                  ),
                  DpadRightIntent: CallbackAction<DpadRightIntent>(
                    onInvoke: (_) {
                      if (_groupsAlphabetActive) return null;
                      _viewerFocus.requestFocus();
                      return null;
                    },
                  ),
                },
                child: ChannelListPanel(
                  key: _groupsChannelPanelKey,
                  selectedCountry: _groups.selectedGroup?.name ?? '',
                  selectedCategory: '',
                  channels: _groups.filteredChannels,
                  selectedChannel: _groups.selectedChannel,
                  onSelect: _selectChannel,
                  onLongPress: () {
                    if (_groups.activateChannelsAlphabetMode()) {
                      _update(() {});
                      FocusScrollSync.requestFocusAtIndex(
                        _groups.alphabetFocusNodes,
                        0,
                      );
                    }
                  },
                  onFocusUp: _focusCurrentTab,
                ),
              );

        return panelWidget;
      },
    );
  }
}
