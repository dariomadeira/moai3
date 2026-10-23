part of '../home_tv_area.dart';

/// Navegación D-pad del área TV: foco, selección de país/categoría/canal/grupo y alfabeto.
extension _TvAreaNavigation on HomeTvAreaState {
  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  void _requestFocusWithRetry(FocusNode node) => _focus.node(node);

  void _activatePanel(TvExplorePanel panel) {
    _update(() => _activePanel = panel);
  }

  VoidCallback get _focusCurrentTab => () {
    if (_tvTab == TvTab.groups) {
      _groupsTabFocus.requestFocus();
    } else if (_tvTab == TvTab.search) {
      _searchTabFocus.requestFocus();
    } else {
      _exploreTabFocus.requestFocus();
    }
  };

  void _focusSelectedCountry() => _focus.selected(_countryPanelKey);

  void _focusSelectedCategory() => _focus.selected(_categoryPanelKey);

  void _focusSelectedChannel() => _focus.selected(_channelPanelKey);

  void _focusGroupsChannel() => _focus.selected(_groupsChannelPanelKey);

  /// Entrada a Buscar: si hay query (X visible) → clear; si no → campo.
  void _focusSearchPanelEntry() {
    if (_search.hasQuery) {
      _requestFocusWithRetry(_search.clearFocusNode);
    } else {
      _requestFocusWithRetry(_search.searchFocusNode);
    }
  }

  /// Error de carga de plugins traducido, o `null` si no hubo error (SPEC-50 §2.1).
  String? _channelLoadErrorMessage() {
    final provider = _channelProvider;
    final key = provider?.channelLoadError;
    if (provider == null || key == null) return null;
    return key.tr(namedArgs: provider.channelLoadErrorArgs);
  }

  void _focusExplorePanel() {
    returnFocusToActivePanel();
  }

  void _focusSelectedGroup() => _focus.selected(_groupListPanelKey);

  void _focusGroupsPanel() {
    if (_groupsPanelIndex == 0) {
      _focusSelectedGroup();
    } else {
      _focusGroupsChannel();
    }
  }

  void _focusActiveContent() {
    // Soltar las tabs y el visor antes de bajar al panel (si no, el foco se queda retenido).
    _exploreTabFocus.unfocus();
    _searchTabFocus.unfocus();
    _groupsTabFocus.unfocus();
    _viewerFocus.unfocus();
    returnFocusToActivePanel();
  }

  /// Smart: enfoca el fav que está on-air o el botón de favoritos si la lista está vacía.
  void _focusViewerFavoritesBar(List<Channel> favChannels, Channel? playing) {
    if (favChannels.isEmpty) {
      if (_favoriteBtnFocus.canRequestFocus) {
        _favoriteBtnFocus.requestFocus();
      } else {
        _viewerFocus.requestFocus();
      }
      return;
    }
    _afterFrame(() {
      _favoritesBar.focusPlayingChannel(favChannels, playing);
    });
  }

  /// Smart: ↑ desde player → Micrófono (si está disponible) / botón ♥ (no la barra). Si es canal adulto, salta a control disponible.
  void _handlePlayerUpKey() {
    if (_watchPartyMicFocusNode.canRequestFocus) {
      _watchPartyMicFocusNode.requestFocus();
      return;
    }
    final channel =
        (_channelProvider ?? context.read<ChannelProvider>()).selectedChannel;
    if (channel != null && channel.isAdult) {
      if (ChannelPlaybackHelpers.playableUrls(channel).length > 1) {
        _serverSkipFocus.requestFocus();
      } else {
        _focusActiveContent();
      }
      return;
    }
    _favoriteBtnFocus.requestFocus();
  }

  void _selectCountry(String country) {
    final channels = context.read<ChannelProvider>().allChannels;
    _browser.selectCountry(country, channels);
    _activatePanel(TvExplorePanel.category);
    _focusSelectedCategory();
  }

  void _selectCategory(String category) {
    final channels = context.read<ChannelProvider>().allChannels;
    _browser.selectCategory(category, channels);
    _activatePanel(TvExplorePanel.channel);
    _focusSelectedChannel();
  }

  void _selectChannel(Channel channel) {
    // Como Smart: Select no mueve el foco al viewer.
    _browser.selectChannel(channel);
    _groups.selectChannel(channel);
    context.read<ChannelProvider>().selectChannel(channel);
  }

  void _selectGroup(ChannelGroup group) {
    final channels = context.read<ChannelProvider>().allChannels;
    final favIds = context.read<FavoritesProvider>().favoriteChannelIds;
    _groups.selectGroup(group, channels, favIds);
    _update(() => _groupsPanelIndex = 1);
    _focusGroupsChannel();
  }

  void _activateAlphabet(TvExplorePanel panel) {
    _search.clearAlphabetMode();
    if (_browser.activateAlphabetMode(panel)) {
      _update(() {});
      // Tras rebuild del acordeón, el ListView de letras necesita reintento.
      FocusScrollSync.requestFocusAtIndex(_browser.alphabetFocusNodes, 0);
    }
  }

  void _activateSearchAlphabet() {
    _browser.clearAlphabetMode();
    if (_search.activateAlphabetMode()) {
      _update(() {});
      FocusScrollSync.requestFocusAtIndex(_search.alphabetFocusNodes, 0);
    }
  }

  void _onSearchAlphabetLetter(String letter) {
    final idx = _search.jumpToLetter(letter);
    _update(() {});
    if (idx == null) return;
    _afterFrame(() => _searchPanelKey.currentState?.focusGlobalIndex(idx));
  }

  bool get _exploreAlphabetActive =>
      _browser.alphabetPanel != null || _search.isAlphabetMode;

  bool get _groupsAlphabetActive => _groups.isAlphabetMode;

  void _focusSearchResults() => _focus.selected(_searchPanelKey);

  void _onAlphabetLetter(String letter) {
    final panel = _browser.jumpToLetter(letter);
    if (panel == null) return;
    _activatePanel(panel);
    switch (panel) {
      case TvExplorePanel.country:
        _focusSelectedCountry();
      case TvExplorePanel.category:
        _focusSelectedCategory();
      case TvExplorePanel.channel:
        _focusSelectedChannel();
      case TvExplorePanel.log:
        break;
    }
  }
}
