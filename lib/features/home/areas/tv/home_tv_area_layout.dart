part of '../home_tv_area.dart';

/// Layout del área TV: pestañas, contenido de cada pestaña, visor y favoritos.
extension _TvAreaLayout on HomeTvAreaState {
  Widget _buildSearchArea(ColorScheme scheme) {
    final alphabetActive = _search.isAlphabetMode;
    final searchPanel = SearchPanel(
      key: _searchPanelKey,
      title: LocaleKeys.home_panel_search.tr(),
      queryController: _search.queryController,
      searchFocusNode: _search.searchFocusNode,
      clearFocusNode: _search.clearFocusNode,
      searchResults: _search.results,
      showSearchPrompt: _search.showSearchPrompt,
      resultsCapped: _search.resultsCapped,
      selectedChannel: _browser.selectedChannel,
      onFocusUp: _focusCurrentTab,
      onLongPress: _activateSearchAlphabet,
      onSelectChannel: _selectChannel,
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (alphabetActive)
            SizedBox(
              width: 38,
              child: AlphabetJumpPanel(
                letters: _search.alphabetLetters,
                focusNodes: _search.alphabetFocusNodes,
                onLetterTap: _onSearchAlphabetLetter,
              ),
            ),
          Expanded(
            child: Actions(
              actions: {
                DpadLeftIntent: CallbackAction<DpadLeftIntent>(
                  onInvoke: (_) {
                    if (_search.isAlphabetMode) return null;
                    widget.onExitLeft();
                    return null;
                  },
                ),
                DpadRightIntent: CallbackAction<DpadRightIntent>(
                  onInvoke: (_) {
                    if (_search.isAlphabetMode) return null;
                    _viewerFocus.requestFocus();
                    return null;
                  },
                ),
              },
              child: alphabetActive
                  ? ExcludeFocus(child: searchPanel)
                  : searchPanel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayout(BuildContext context) {
    final scheme = context.scheme;
    final showTvLog = context.select((TvSettingsProvider s) => s.showTvLog);
    final channel = context.select((ChannelProvider s) => s.selectedChannel);
    final allChannels = context.select((ChannelProvider s) => s.allChannels);

    final favChannels = _favorites.favoriteChannels;
    final showServerSkip =
        channel != null &&
        ChannelPlaybackHelpers.playableUrls(channel).length > 1;

    final panelCount = TvPanelLayout.panels(showTvLog).length;
    final active = TvPanelLayout.indexOf(_activePanel, showTvLog);
    final alphabetPanel = _browser.alphabetPanel;
    final exploreAlphabetPanelIndex = alphabetPanel == null
        ? null
        : TvPanelLayout.indexOf(alphabetPanel, showTvLog);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TvTabBar(
                      selectedTab: _tvTab,
                      onTabChanged: (tab) {
                        _update(() => _tvTab = tab);
                        _afterFrame(_focusActiveContent);
                      },
                      exploreFocusNode: _exploreTabFocus,
                      searchFocusNode: _searchTabFocus,
                      groupsFocusNode: _groupsTabFocus,
                      onFocusDown: _focusActiveContent,
                      onFocusLeft: widget.onExitLeft,
                      onFocusPlayer: () {
                        if (_watchPartyMicFocusNode.canRequestFocus) {
                          _watchPartyMicFocusNode.requestFocus();
                        } else {
                          _viewerFocus.requestFocus();
                        }
                      },
                    ),
                    Expanded(
                      child: _tvTab == TvTab.explore
                          ? TvAccordionRowPreview(
                              panelCount: panelCount,
                              activeIndex: active,
                              colors: List.filled(
                                panelCount,
                                scheme.surface.withValues(alpha: 0.8),
                              ),
                              titles: _titles(showTvLog),
                              icons: _icons(showTvLog),
                              alphabetModePanelIndex: exploreAlphabetPanelIndex,
                              alphabetPanelBuilder: (_) => AlphabetJumpPanel(
                                letters: _browser.alphabetLetters,
                                focusNodes: _browser.alphabetFocusNodes,
                                onLetterTap: _onAlphabetLetter,
                              ),
                              onPanelTap: (i) {
                                if (_exploreAlphabetActive) return;
                                _activatePanel(
                                  TvPanelLayout.panelAt(i, showTvLog),
                                );
                                _focusExplorePanel();
                              },
                              buildExpandedContent: (i, t) =>
                                  _buildExploreExpanded(
                                    TvPanelLayout.panelAt(i, showTvLog),
                                    t,
                                    showTvLog,
                                  ),
                            )
                          : _tvTab == TvTab.search
                          ? _buildSearchArea(scheme)
                          : _buildGroupsAccordion(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: RepaintBoundary(
                child: channel == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 3,
                              bottom: 12,
                              right: 8,
                            ),
                            child: SizedBox(
                              height: 40,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: TvWatchPartyHeaderBar(
                                  micFocusNode: _watchPartyMicFocusNode,
                                  onLongPressMic: () =>
                                      TvFriendsDialog.show(context),
                                  onKeyLeft: () {
                                    if (_groupsTabFocus.canRequestFocus) {
                                      _groupsTabFocus.requestFocus();
                                    } else if (_searchTabFocus
                                        .canRequestFocus) {
                                      _searchTabFocus.requestFocus();
                                    } else {
                                      _exploreTabFocus.requestFocus();
                                    }
                                  },
                                  onKeyUp: () {
                                    if (_groupsTabFocus.canRequestFocus) {
                                      _groupsTabFocus.requestFocus();
                                    } else {
                                      _exploreTabFocus.requestFocus();
                                    }
                                  },
                                  onKeyDown: _viewerFocus.requestFocus,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: EmptyViewerPanel(
                              focusNode: _viewerFocus,
                              hasChannels: allChannels.isNotEmpty,
                              onReturnToPanel: _focusActiveContent,
                              onKeyUp: () {
                                if (_watchPartyMicFocusNode.canRequestFocus) {
                                  _watchPartyMicFocusNode.requestFocus();
                                } else {
                                  _focusCurrentTab();
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TvViewerPanel(
                            channel: channel,
                            header: TvWatchPartyHeaderBar(
                              channelName: channel.name,
                              micFocusNode: _watchPartyMicFocusNode,
                              onLongPressMic: () =>
                                  TvFriendsDialog.show(context),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 12,
                              ),
                              child: TvPlayerLayoutAnchor(
                                overlayController: _playerOverlay,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ViewerFavoritesBar(
                              favoriteChannels: favChannels,
                              selectedChannel: channel,
                              scrollController: _favoritesBar.scrollController,
                              focusNodes: _favoritesBar.focusNodes,
                              headerAction: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (favChannels.isNotEmpty) ...[
                                    CreateGroupButton(
                                      focusNode: _createGroupFocus,
                                      onKeyLeft: _focusActiveContent,
                                      onKeyRight:
                                          _clearFavoritesFocus.requestFocus,
                                      onKeyUp: _viewerFocus.requestFocus,
                                      onKeyDown: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    ClearFavoritesButton(
                                      focusNode: _clearFavoritesFocus,
                                      onKeyLeft: _createGroupFocus.requestFocus,
                                      onKeyRight: !channel.isAdult
                                          ? _favoriteBtnFocus.requestFocus
                                          : null,
                                      onKeyUp: _viewerFocus.requestFocus,
                                      onKeyDown: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                    ),
                                    if (!channel.isAdult)
                                      const SizedBox(width: 6),
                                  ],
                                  if (!channel.isAdult)
                                    FavoriteButton(
                                      channel: channel,
                                      focusNode: _favoriteBtnFocus,
                                      onKeyUp: _viewerFocus.requestFocus,
                                      onKeyDown: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                      onKeyLeft: favChannels.isNotEmpty
                                          ? _clearFavoritesFocus.requestFocus
                                          : _focusActiveContent,
                                      onKeyRight: showServerSkip
                                          ? _serverSkipFocus.requestFocus
                                          : null,
                                    ),
                                  if (showServerSkip) ...[
                                    if (!channel.isAdult ||
                                        favChannels.isNotEmpty)
                                      const SizedBox(width: 6),
                                    ServerSkipButton(
                                      focusNode: _serverSkipFocus,
                                      onKeyUp: _viewerFocus.requestFocus,
                                      onKeyDown: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                      onKeyLeft: !channel.isAdult
                                          ? _favoriteBtnFocus.requestFocus
                                          : (favChannels.isNotEmpty
                                                ? _clearFavoritesFocus
                                                      .requestFocus
                                                : _focusActiveContent),
                                    ),
                                  ],
                                ],
                              ),
                              onSelect: _selectChannel,
                              onFocusPrevious: _favoritesBar.focusPrevious,
                              onFocusNext: (i) => _favoritesBar.focusNext(
                                i,
                                _favoritesBar.focusNodes.length,
                              ),
                              onFocusLeft: _focusSelectedChannel,
                              onFocusRight: _viewerFocus.requestFocus,
                              onKeyUp: () {
                                if (!channel.isAdult &&
                                    _favoriteBtnFocus.canRequestFocus) {
                                  _favoriteBtnFocus.requestFocus();
                                } else if (favChannels.isNotEmpty &&
                                    _clearFavoritesFocus.canRequestFocus) {
                                  _clearFavoritesFocus.requestFocus();
                                } else if (favChannels.isNotEmpty &&
                                    _createGroupFocus.canRequestFocus) {
                                  _createGroupFocus.requestFocus();
                                } else {
                                  _viewerFocus.requestFocus();
                                }
                              },
                              onKeyDown: _viewerFocus.requestFocus,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
        if (channel != null)
          TvPlayerOverlay(
            channel: channel,
            overlayController: _playerOverlay,
            focusNode: _viewerFocus,
            onRequestListFocus: _focusActiveContent,
            onRequestUpFocus: _handlePlayerUpKey,
          ),
      ],
    );
  }
}
