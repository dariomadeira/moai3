import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/features/channel_browser/widgets/category_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/channel_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/country_list_panel.dart';
import 'package:moai3/features/favorites/controllers/favorites_list_controller.dart';
import 'package:moai3/features/groups/controllers/groups_browser_controller.dart';
import 'package:moai3/features/groups/widgets/group_list_panel.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/controllers/player_overlay_controller.dart';
import 'package:moai3/features/home/controllers/viewer_favorites_controller.dart';
import 'package:moai3/features/home/widgets/alphabet_jump_panel.dart';
import 'package:moai3/features/home/widgets/channel_viewer_header.dart';
import 'package:moai3/features/home/widgets/empty_viewer_panel.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_tab_bar.dart';
import 'package:moai3/features/home/widgets/tv_clock_pill.dart';
import 'package:moai3/features/home/widgets/tv_watch_party_header_bar.dart';
import 'package:moai3/features/home/widgets/viewer_favorites_bar.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/features/search/widgets/search_panel.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_focus_controller.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/layout/tv_panel_layout.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/clear_favorites_button.dart';
import 'package:moai3/widgets/buttons/create_group_button.dart';
import 'package:moai3/widgets/buttons/favorite_button.dart';
import 'package:moai3/widgets/buttons/simulate_live_button.dart';
import 'package:moai3/widgets/buttons/server_skip_button.dart';
import 'package:moai3/widgets/feedback/debug_log_panel.dart';
import 'package:moai3/widgets/player/tv_player_overlay.dart';

/// Área TV: Explorar / Grupos + viewer + player overlay + favoritos.
///
/// Contrato de foco = moaiSmart: Shortcuts globales en [HomeScreen];
/// → del rail llama [HomeTvAreaState.requestEntryFocus].
class HomeTvArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  const HomeTvArea({
    super.key,
    required this.onExitLeft,
  });

  @override
  State<HomeTvArea> createState() => HomeTvAreaState();
}

class HomeTvAreaState extends HomeAreaState<HomeTvArea>
    with WidgetsBindingObserver {
  static const bool _showSimulateLiveButtons = false;
  final _browser = ChannelBrowserController();
  final _search = HomeSearchController();
  final _groups = GroupsBrowserController();
  final _favorites = FavoritesListController();
  final _favoritesBar = ViewerFavoritesController();
  final _playerOverlay = PlayerOverlayController();
  final _tvFocus = TvFocusController();

  final _exploreTabFocus = FocusNode(
    debugLabel: 'tv_tab_explore',
    skipTraversal: true,
  );
  final _searchTabFocus = FocusNode(
    debugLabel: 'tv_tab_search',
    skipTraversal: true,
  );
  final _groupsTabFocus = FocusNode(
    debugLabel: 'tv_tab_groups',
    skipTraversal: true,
  );
  final _viewerFocus = FocusNode(debugLabel: 'tv_viewer');
  final _favoriteBtnFocus = FocusNode(debugLabel: 'tv_fav_btn');
  final _createGroupFocus = FocusNode(debugLabel: 'tv_create_group_btn');
  final _clearFavoritesFocus = FocusNode(debugLabel: 'tv_clear_fav_btn');
  final _simulateLiveFocus = FocusNode(debugLabel: 'tv_simulate_live');
  final _simulateLiveTwoFocus = FocusNode(debugLabel: 'tv_simulate_live_two');
  final _serverSkipFocus = FocusNode(debugLabel: 'tv_server_skip');
  final _logFocus = FocusNode(debugLabel: 'tv_log');
  final _watchPartyMicFocusNode = FocusNode(debugLabel: 'tv_header_mic');
  final _countryPanelKey = GlobalKey<CountryListPanelState>();
  final _categoryPanelKey = GlobalKey<CategoryListPanelState>();
  final _channelPanelKey = GlobalKey<ChannelListPanelState>();
  final _groupsChannelPanelKey = GlobalKey<ChannelListPanelState>();
  final _groupListPanelKey = GlobalKey<GroupListPanelState>();
  final _searchPanelKey = GlobalKey<SearchPanelState>();

  String _tvTab = 'explore';
  int _activePanelIndex = 0;
  int _groupsPanelIndex = 0;
  bool _initialized = false;
  bool _lastShowTvLog = false;
  String? _lastPlayingChannelId;
  List<String> _lastChannelIds = [];
  List<String> _lastFavoriteIds = [];
  List<String> _lastGroupIds = [];
  double _lastOverlapX = -1;
  double _lastOverlapY = -1;
  bool _lastIsAdultUnlocked = false;
  ChannelProvider? _channelProvider;
  TvSettingsProvider? _tvSettingsProvider;
  FavoritesProvider? _favoritesProvider;
  StreamSubscription<String>? _joinedNotificationsSubscription;

  @override
  void initState() {
    super.initState();
    _search.initialize();
    _browser.addListener(_rebuild);
    _search.addListener(_rebuild);
    _groups.addListener(_rebuild);
    _favorites.addListener(_rebuild);
    _playerOverlay.addListener(_onPlayerOverlayChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestInitialPlayerFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _channelProvider = context.read<ChannelProvider>();
    _tvSettingsProvider = context.read<TvSettingsProvider>();
    _favoritesProvider = context.read<FavoritesProvider>();

    final wp = context.read<WatchPartyProvider?>();
    if (wp != null) {
      _joinedNotificationsSubscription?.cancel();
      _joinedNotificationsSubscription =
          wp.joinedChannelNotificationsStream.listen((friendName) {
        if (!mounted) return;
        MoaiSnackBar.show(
          context,
          message: 'watch_party_friend_joined'.tr(namedArgs: {'name': friendName}),
          icon: Symbols.person,
        );
      });
    }

    _channelProvider!.addListener(_onStateChanged);
    _tvSettingsProvider!.addListener(_onStateChanged);
    _favoritesProvider!.addListener(_onStateChanged);

    _lastIsAdultUnlocked = _tvSettingsProvider!.isAdultUnlocked;

    _search.attachQueryListener(
      () => _channelProvider!.allChannels,
      isAdultUnlocked: () => _tvSettingsProvider?.isAdultUnlocked ?? false,
    );

    _lastShowTvLog = _tvSettingsProvider!.showTvLog;
    _activePanelIndex = TvPanelLayout.channelPanelIndex(_lastShowTvLog);
    _lastChannelIds = _channelProvider!.allChannels.map((c) => c.id).toList();
    _lastFavoriteIds = List.from(_favoritesProvider!.favoriteChannelIds);
    _lastGroupIds = _channelProvider!.groups.map((g) => g.id).toList();
    _lastOverlapX = _tvSettingsProvider!.overlapPaddingX;
    _lastOverlapY = _tvSettingsProvider!.overlapPaddingY;

    _browser.initializeFromChannels(
      _channelProvider!.allChannels,
      initial: _channelProvider!.selectedChannel,
      isAdultUnlocked: _lastIsAdultUnlocked,
    );
    _favorites.syncFrom(
      _channelProvider!.allChannels,
      _favoritesProvider!.favoriteChannelIds,
      isAdultUnlocked: _lastIsAdultUnlocked,
    );
    _favoritesBar.syncFrom(
      _favorites.favoriteChannels.length,
    );
    _groups.syncFrom(
      _channelProvider!.groups,
      _channelProvider!.allChannels,
      _favoritesProvider!.favoriteChannelIds,
      isAdultUnlocked: _lastIsAdultUnlocked,
    );

    final initial = _channelProvider!.selectedChannel;
    if (initial != null) {
      _lastPlayingChannelId = initial.id;
      _groups.selectChannel(initial);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _schedulePlaceholderRectUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updatePlaceholderRect();
    });
  }

  void _onPlayerOverlayChanged() {
    _rebuild();
    _schedulePlaceholderRectUpdate();
  }

  void _updatePlaceholderRect() {
    _playerOverlay.updatePlaceholderRect(retryIfInvalid: true);
    if (_playerOverlay.shouldRequestInitialFocus(false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _viewerFocus.requestFocus();
        _playerOverlay.markInitialFocusDone();
      });
    }
  }

  void _requestInitialPlayerFocus([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || attempt > 30) return;
      if (_playerOverlay.hasValidRect) {
        _viewerFocus.requestFocus();
        _playerOverlay.markInitialFocusDone();
      } else {
        _requestInitialPlayerFocus(attempt + 1);
      }
    });
  }

  void _onStateChanged() {
    if (!mounted) return;
    final tvSettings = _tvSettingsProvider ?? context.read<TvSettingsProvider>();
    final channelProv = _channelProvider ?? context.read<ChannelProvider>();
    final favProv = _favoritesProvider ?? context.read<FavoritesProvider>();

    final showTvLog = tvSettings.showTvLog;
    if (showTvLog != _lastShowTvLog) {
      setState(() {
        _lastShowTvLog = showTvLog;
        _activePanelIndex = TvPanelLayout.channelPanelIndex(showTvLog);
      });
    }

    final isAdultUnlocked = tvSettings.isAdultUnlocked;
    final adultUnlockedChanged = isAdultUnlocked != _lastIsAdultUnlocked;
    if (adultUnlockedChanged) {
      _lastIsAdultUnlocked = isAdultUnlocked;
      if (!isAdultUnlocked) {
        channelProv.onAdultLocked();
      }
      if (_search.queryController.text.isNotEmpty) {
        _search.updateResults(
          channelProv.allChannels,
          _search.queryController.text,
          isAdultUnlocked: isAdultUnlocked,
        );
      }
    }

    final channels = channelProv.allChannels;
    final favIds = favProv.favoriteChannelIds;
    final groupIds = channelProv.groups.map((g) => g.id).toList();
    final channelIds = channels.map((c) => c.id).toList();
    final channelsChanged = !_sameStringList(channelIds, _lastChannelIds);
    final favIdsChanged = !_sameStringList(favIds, _lastFavoriteIds);
    final groupsChanged = !_sameStringList(groupIds, _lastGroupIds);

    if (channelsChanged || adultUnlockedChanged) {
      _lastChannelIds = List.from(channelIds);
      if (_browser.countries.isEmpty && channels.isNotEmpty) {
        _browser.initializeFromChannels(
          channels,
          initial: channelProv.selectedChannel,
          isAdultUnlocked: isAdultUnlocked,
        );
        final initial = channelProv.selectedChannel;
        if (initial != null) {
          _lastPlayingChannelId = initial.id;
          _groups.selectChannel(initial);
        }
      } else {
        _browser.syncFromChannels(channels, isAdultUnlocked: isAdultUnlocked);
      }
    }

    if (channelsChanged || favIdsChanged || groupsChanged || adultUnlockedChanged) {
      if (favIdsChanged) {
        _lastFavoriteIds = List.from(favIds);
      }
      if (groupsChanged) {
        _lastGroupIds = List.from(groupIds);
      }
      _favorites.syncFrom(channels, favIds, isAdultUnlocked: isAdultUnlocked);
      favProv.sanitizeAdultFavorites(channels);
      _favoritesBar.syncFrom(
        _favorites.favoriteChannels.length,
      );
      _groups.syncFrom(channelProv.groups, channels, favIds,
          isAdultUnlocked: isAdultUnlocked);
    }

    final playingChannel = channelProv.selectedChannel;
    if (playingChannel?.id != _lastPlayingChannelId) {
      _lastPlayingChannelId = playingChannel?.id;
      if (playingChannel != null) {
        _browser.syncPlayingChannel(playingChannel, channels);
        _groups.selectChannel(playingChannel);
      } else if (channels.isEmpty) {
        _browser.syncFromChannels(channels);
      }
    }

    if (tvSettings.overlapPaddingX != _lastOverlapX ||
        tvSettings.overlapPaddingY != _lastOverlapY) {
      _lastOverlapX = tvSettings.overlapPaddingX;
      _lastOverlapY = tvSettings.overlapPaddingY;
      _schedulePlaceholderRectUpdate();
    }

    if (_playerOverlay.shouldRequestInitialFocus(channelProv.isLoadingChannels)) {
      _requestInitialPlayerFocus();
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _schedulePlaceholderRectUpdate();
  }

  @override
  void dispose() {
    _joinedNotificationsSubscription?.cancel();
    _channelProvider?.removeListener(_onStateChanged);
    _tvSettingsProvider?.removeListener(_onStateChanged);
    _favoritesProvider?.removeListener(_onStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _browser.removeListener(_rebuild);
    _search.removeListener(_rebuild);
    _groups.removeListener(_rebuild);
    _favorites.removeListener(_rebuild);
    _playerOverlay.removeListener(_onPlayerOverlayChanged);
    _browser.dispose();
    _search.dispose();
    _groups.dispose();
    _favorites.dispose();
    _favoritesBar.dispose();
    _playerOverlay.dispose();
    _exploreTabFocus.dispose();
    _searchTabFocus.dispose();
    _groupsTabFocus.dispose();
    _viewerFocus.dispose();
    _favoriteBtnFocus.dispose();
    _createGroupFocus.dispose();
    _clearFavoritesFocus.dispose();
    _watchPartyMicFocusNode.dispose();
    _simulateLiveFocus.dispose();
    _simulateLiveTwoFocus.dispose();
    _serverSkipFocus.dispose();
    _logFocus.dispose();
    super.dispose();
  }

  void _afterFrame(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  /// Igual que Settings / Smart: esperar a que el nodo exista en el árbol.
  void _requestFocusWithRetry(FocusNode node, [int attempts = 15]) {
    requestFocusWithRetry(node, isMounted: () => mounted, attempts: attempts);
  }

  void _activatePanel(int index) {
    setState(() => _activePanelIndex = index);
  }

  VoidCallback get _focusCurrentTab => () {
    if (_watchPartyMicFocusNode.canRequestFocus) {
      _watchPartyMicFocusNode.requestFocus();
      return;
    }
    if (_tvTab == 'groups') {
      _groupsTabFocus.requestFocus();
    } else if (_tvTab == 'search') {
      _searchTabFocus.requestFocus();
    } else {
      _exploreTabFocus.requestFocus();
    }
  };

  void _focusSelectedCountry([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _countryPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusSelectedCountry(attempts - 1);
      }
    });
  }

  void _focusSelectedCategory([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _categoryPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusSelectedCategory(attempts - 1);
      }
    });
  }

  void _focusSelectedChannel([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _channelPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusSelectedChannel(attempts - 1);
      }
    });
  }

  void _focusGroupsChannel([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _groupsChannelPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusGroupsChannel(attempts - 1);
      }
    });
  }

  /// Entrada a Buscar: si hay query (X visible) → clear; si no → campo.
  void _focusSearchPanelEntry() {
    if (_search.hasQuery) {
      _requestFocusWithRetry(_search.clearFocusNode);
    } else {
      _requestFocusWithRetry(_search.searchFocusNode);
    }
  }

  /// Público: lo llama el rail con → (Smart: `_returnFocusToActivePanel`).
  @override
  void requestEntryFocus() => returnFocusToActivePanel();

  void returnFocusToActivePanel() {
    if (_tvTab == 'groups') {
      _focusGroupsPanel();
      return;
    }
    if (_tvTab == 'search') {
      _focusSearchPanelEntry();
      return;
    }
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    _tvFocus.restoreAfterRailRight(
      activePanelIndex: _activePanelIndex,
      showTvLog: showTvLog,
      focusDebug: () => _requestFocusWithRetry(_logFocus),
      focusCountry: _focusSelectedCountry,
      focusCategory: _focusSelectedCategory,
      focusChannel: _focusSelectedChannel,
    );
  }

  bool get isPlayerFullScreen => _playerOverlay.isFullScreen;

  /// Back del D-pad / sistema. `true` si se consumió (no salir de la app).
  bool handleBack() {
    final now = DateTime.now();
    if (_playerOverlay.isFullScreen) {
      _playerOverlay.setFullScreen(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _viewerFocus.canRequestFocus) {
          _viewerFocus.requestFocus();
        }
      });
      return true;
    }
    if (_playerOverlay.lastExitFullScreenTime != null &&
        now.difference(_playerOverlay.lastExitFullScreenTime!) <
            const Duration(milliseconds: 600)) {
      return true;
    }
    if (_search.isAlphabetMode) {
      _search.clearAlphabetMode();
      setState(() {});
      _focusSearchResults();
      return true;
    }
    if (_browser.alphabetModePanelIndex != null) {
      _browser.clearAlphabetMode();
      setState(() {});
      _focusExplorePanel();
      return true;
    }
    if (_groups.isAlphabetMode) {
      _groups.clearAlphabetMode();
      setState(() {});
      _focusGroupsPanel();
      return true;
    }
    return false;
  }

  void _focusExplorePanel() {
    returnFocusToActivePanel();
  }

  void _focusSelectedGroup([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _groupListPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusSelectedGroup(attempts - 1);
      }
    });
  }

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
      if (ChannelPlaybackHelpers.playableUrls(channel).length > 1 &&
          !(_channelProvider?.isPuppeteerEngine ?? false)) {
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
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    _browser.selectCountry(country, channels);
    _activatePanel(_browser.categoryPanelIndexAfterCountrySelect(showTvLog));
    _focusSelectedCategory();
  }

  void _selectCategory(String category) {
    final channels = context.read<ChannelProvider>().allChannels;
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    _browser.selectCategory(category, channels);
    _activatePanel(
      _browser.channelPanelIndexAfterCategorySelect(showTvLog),
    );
    _focusSelectedChannel();
  }

  void _selectChannel(Channel channel) {
    // Como Smart: Select no mueve el foco al viewer.
    _browser.selectChannel(channel);
    _groups.selectChannel(channel);
    context.read<ChannelProvider>().selectChannel(channel);
  }

  /// Permite a áreas externas (ej. Calendario) sintonizar un canal directamente.
  void selectChannel(Channel channel) => _selectChannel(channel);

  /// Solicita foco para el reproductor de TV desde áreas externas tras sintonizar.
  void requestViewerFocus() {
    if (mounted && _viewerFocus.canRequestFocus) {
      _viewerFocus.requestFocus();
    }
  }

  void _selectGroup(ChannelGroup group) {
    final channels = context.read<ChannelProvider>().allChannels;
    final favIds = context.read<FavoritesProvider>().favoriteChannelIds;
    _groups.selectGroup(group, channels, favIds);
    setState(() => _groupsPanelIndex = 1);
    _focusGroupsChannel();
  }

  void _activateAlphabet(int panelIndex) {
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    _search.clearAlphabetMode();
    if (_browser.activateAlphabetMode(panelIndex, showTvLog)) {
      setState(() {});
      // Tras rebuild del acordeón, el ListView de letras necesita reintento.
      FocusScrollSync.requestFocusAtIndex(_browser.alphabetFocusNodes, 0);
    }
  }

  void _activateSearchAlphabet() {
    _browser.clearAlphabetMode();
    if (_search.activateAlphabetMode()) {
      setState(() {});
      FocusScrollSync.requestFocusAtIndex(_search.alphabetFocusNodes, 0);
    }
  }

  void _onSearchAlphabetLetter(String letter) {
    final idx = _search.jumpToLetter(letter);
    setState(() {});
    if (idx == null) return;
    _afterFrame(() => _searchPanelKey.currentState?.focusGlobalIndex(idx));
  }

  bool get _exploreAlphabetActive =>
      _browser.alphabetModePanelIndex != null || _search.isAlphabetMode;

  bool get _groupsAlphabetActive => _groups.isAlphabetMode;

  void _focusSearchResults([int attempts = 15]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _searchPanelKey.currentState;
      if (state != null) {
        state.focusSelected();
      } else if (attempts > 0) {
        _focusSearchResults(attempts - 1);
      }
    });
  }

  void _onAlphabetLetter(String letter) {
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    final panel = _browser.jumpToLetter(letter, showTvLog);
    if (panel == null) return;
    setState(() => _activePanelIndex = panel);
    if (TvPanelLayout.isCountryPanel(panel, showTvLog)) {
      _focusSelectedCountry();
    } else if (TvPanelLayout.isCategoryPanel(panel, showTvLog)) {
      _focusSelectedCategory();
    } else if (TvPanelLayout.isChannelPanel(panel, showTvLog)) {
      _focusSelectedChannel();
    }
  }

  List<String> _titles(bool showTvLog) {
    final base = [
      'home_panel_countries'.tr(),
      'home_panel_categories'.tr(),
      'home_panel_channels'.tr(),
    ];
    return TvPanelLayout.hasLogPanel(showTvLog)
        ? ['home_panel_tv_log'.tr(), ...base]
        : base;
  }

  List<IconData> _icons(bool showTvLog) {
    final base = [
      Icons.grid_view_outlined,
      Icons.category_outlined,
      Icons.live_tv_outlined,
    ];
    return TvPanelLayout.hasLogPanel(showTvLog)
        ? [Icons.bug_report_outlined, ...base]
        : base;
  }

  Widget _buildExploreExpanded(int index, String title, bool showTvLog) {
    if (TvPanelLayout.isLogPanel(index, showTvLog)) {
      return DebugLogPanel(
        focusNode: _logFocus,
        onKeyLeft: widget.onExitLeft,
        onKeyRight: () {
          _activatePanel(TvPanelLayout.countryPanelIndex(showTvLog));
          _focusSelectedCountry();
        },
      );
    }

    if (TvPanelLayout.isCountryPanel(index, showTvLog)) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              if (TvPanelLayout.hasLogPanel(showTvLog)) {
                _activatePanel(TvPanelLayout.logPanelIndex(showTvLog));
                _requestFocusWithRetry(_logFocus);
              } else {
                widget.onExitLeft();
              }
              return null;
            },
          ),
          DpadRightIntent: CallbackAction<DpadRightIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvPanelLayout.categoryPanelIndex(showTvLog));
              _focusSelectedCategory();
              return null;
            },
          ),
        },
        child: CountryListPanel(
          key: _countryPanelKey,
          title: title,
          countries: _browser.countries,
          selectedCountry: _browser.selectedCountry,
          onSelect: _selectCountry,
          onLongPress: () =>
              _activateAlphabet(TvPanelLayout.countryPanelIndex(showTvLog)),
          onFocusUp: _focusCurrentTab,
        ),
      );
    }

    if (TvPanelLayout.isCategoryPanel(index, showTvLog)) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvPanelLayout.countryPanelIndex(showTvLog));
              _focusSelectedCountry();
              return null;
            },
          ),
          DpadRightIntent: CallbackAction<DpadRightIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvPanelLayout.channelPanelIndex(showTvLog));
              _focusSelectedChannel();
              return null;
            },
          ),
        },
        child: CategoryListPanel(
          key: _categoryPanelKey,
          title: title,
          selectedCountry: _browser.selectedCountry,
          categories: _browser.categories,
          selectedCategory: _browser.selectedCategory,
          onSelect: _selectCategory,
          onLongPress: () =>
              _activateAlphabet(TvPanelLayout.categoryPanelIndex(showTvLog)),
          onFocusUp: _focusCurrentTab,
        ),
      );
    }

    return Actions(
      actions: {
        DpadLeftIntent: CallbackAction<DpadLeftIntent>(
          onInvoke: (_) {
            if (_exploreAlphabetActive) return null;
            _activatePanel(TvPanelLayout.categoryPanelIndex(showTvLog));
            _focusSelectedCategory();
            return null;
          },
        ),
        DpadRightIntent: CallbackAction<DpadRightIntent>(
          onInvoke: (_) {
            if (_exploreAlphabetActive) return null;
            _viewerFocus.requestFocus();
            return null;
          },
        ),
      },
      child: ChannelListPanel(
        key: _channelPanelKey,
        selectedCountry: _browser.selectedCountry,
        selectedCategory: _browser.selectedCategory,
        channels: _browser.channels,
        selectedChannel: _browser.selectedChannel,
        onSelect: _selectChannel,
        onLongPress: () =>
            _activateAlphabet(TvPanelLayout.channelPanelIndex(showTvLog)),
        onFocusUp: _focusCurrentTab,
      ),
    );
  }

  Widget _buildGroupsAccordion(BuildContext context) {
    final scheme = context.scheme;
    final channelProv = context.read<ChannelProvider>();
    final favProv = context.read<FavoritesProvider>();

    return TvAccordionRowPreview(
      panelCount: 2,
      activeIndex: _groupsPanelIndex,
      colors: [scheme.surface, scheme.surface],
      titles: [
        'home_panel_groups'.tr(),
        'home_panel_channels'.tr(),
      ],
      icons: const [Symbols.bookmarks, Icons.live_tv_outlined],
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
          _groups.syncFrom(channelProv.groups, channelProv.allChannels,
              favProv.favoriteChannelIds,
              isAdultUnlocked: _lastIsAdultUnlocked);
          setState(() {});
        },
        onLetterTap: (letter) {
          final channelIdx = _groups.jumpToLetter(
            letter,
            channelProv.allChannels,
            favProv.favoriteChannelIds,
          );
          setState(() {});
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
        setState(() => _groupsPanelIndex = i);
        _focusGroupsPanel();
      },
      buildExpandedContent: (index, title) {
        if (index == 0) {
          return Actions(
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
                  setState(() => _groupsPanelIndex = 1);
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
                  setState(() {});
                  FocusScrollSync.requestFocusAtIndex(
                    _groups.alphabetFocusNodes,
                    0,
                  );
                }
              },
              onFocusUp: _focusCurrentTab,
            ),
          );
        }
        return Actions(
          actions: {
            DpadLeftIntent: CallbackAction<DpadLeftIntent>(
              onInvoke: (_) {
                if (_groupsAlphabetActive) return null;
                setState(() => _groupsPanelIndex = 0);
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
                setState(() {});
                FocusScrollSync.requestFocusAtIndex(
                  _groups.alphabetFocusNodes,
                  0,
                );
              }
            },
            onFocusUp: _focusCurrentTab,
          ),
        );
      },
    );
  }

  Widget _buildSearchArea(ColorScheme scheme) {
    final alphabetActive = _search.isAlphabetMode;
    final searchPanel = SearchPanel(
      key: _searchPanelKey,
      title: 'home_panel_search'.tr(),
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
        color: scheme.surface,
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final showTvLog = context.select((TvSettingsProvider s) => s.showTvLog);
    final channel = context.select((ChannelProvider s) => s.selectedChannel);
    final allChannels = context.select((ChannelProvider s) => s.allChannels);
    final isPuppeteer =
        context.select((ChannelProvider s) => s.isPuppeteerEngine);

    final favChannels = _favorites.favoriteChannels;
    final showServerSkip = channel != null &&
        ChannelPlaybackHelpers.playableUrls(channel).length > 1 &&
        !isPuppeteer;
    final showBottomControls = showServerSkip || _showSimulateLiveButtons;

    final panelCount = TvPanelLayout.panelCount(showTvLog);
    final active = _activePanelIndex.clamp(0, panelCount - 1);
    final exploreAlphabetPanelIndex = _browser.alphabetModePanelIndex;

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
                        setState(() => _tvTab = tab);
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
                      child: _tvTab == 'explore'
                          ? TvAccordionRowPreview(
                              panelCount: panelCount,
                              activeIndex: active,
                              colors:
                                  List.filled(panelCount, scheme.surface),
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
                                _activatePanel(i);
                                _focusExplorePanel();
                              },
                              buildExpandedContent: (i, t) =>
                                  _buildExploreExpanded(i, t, showTvLog),
                            )
                          : _tvTab == 'search'
                              ? _buildSearchArea(scheme)
                              : _buildGroupsAccordion(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: TvWatchPartyHeaderBar(
                              micFocusNode: _watchPartyMicFocusNode,
                              onLongPressMic: () => TvFriendsDialog.show(context),
                              onKeyLeft: () {
                                if (_groupsTabFocus.canRequestFocus) {
                                  _groupsTabFocus.requestFocus();
                                } else if (_searchTabFocus.canRequestFocus) {
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
                              onKeyDown: () => _viewerFocus.requestFocus(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const TvClockPill(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: channel == null
                    ? EmptyViewerPanel(
                        focusNode: _viewerFocus,
                        hasChannels: allChannels.isNotEmpty,
                        onReturnToPanel: _focusActiveContent,
                        onKeyUp: _focusCurrentTab,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: TvLayoutConstants
                                    .viewerHorizontalPaddingStart,
                                right: TvLayoutConstants
                                    .viewerHorizontalPaddingEnd,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ChannelViewerHeader(channel: channel),
                                  Expanded(
                                    child: Center(
                                      child: TvPlayerLayoutAnchor(
                                        overlayController: _playerOverlay,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: TvLayoutConstants.viewerSectionGap,
                          ),
                          ViewerFavoritesBar(
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
                                    onKeyRight: () =>
                                        _clearFavoritesFocus.requestFocus(),
                                    onKeyUp: () => _viewerFocus.requestFocus(),
                                    onKeyDown: () => _focusViewerFavoritesBar(
                                      favChannels,
                                      channel,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ClearFavoritesButton(
                                    focusNode: _clearFavoritesFocus,
                                    onKeyLeft: () =>
                                        _createGroupFocus.requestFocus(),
                                    onKeyRight: !channel.isAdult
                                        ? () =>
                                            _favoriteBtnFocus.requestFocus()
                                        : null,
                                    onKeyUp: () => _viewerFocus.requestFocus(),
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
                                    onKeyUp: () => _viewerFocus.requestFocus(),
                                    onKeyDown: () => _focusViewerFavoritesBar(
                                      favChannels,
                                      channel,
                                    ),
                                    onKeyLeft: favChannels.isNotEmpty
                                        ? () =>
                                            _clearFavoritesFocus.requestFocus()
                                        : _focusActiveContent,
                                    onKeyRight: () {},
                                  ),
                              ],
                            ),
                            onSelect: _selectChannel,
                            onFocusPrevious: _favoritesBar.focusPrevious,
                            onFocusNext: (i) => _favoritesBar.focusNext(
                              i,
                              _favoritesBar.focusNodes.length,
                            ),
                            onFocusLeft: _focusSelectedChannel,
                            onFocusRight: () => _viewerFocus.requestFocus(),
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
                            onKeyDown: () {
                              if (showServerSkip) {
                                _serverSkipFocus.requestFocus();
                              } else {
                                _viewerFocus.requestFocus();
                              }
                            },
                          ),
                          if (showBottomControls) ...[
                            const SizedBox(
                              height: TvLayoutConstants.viewerSectionGap,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: TvLayoutConstants
                                    .viewerHorizontalPaddingStart,
                                right: TvLayoutConstants
                                    .viewerHorizontalPaddingEnd,
                                bottom: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (showServerSkip)
                                    ServerSkipButton(
                                      focusNode: _serverSkipFocus,
                                      onKeyLeft: _focusActiveContent,
                                      onKeyRight: () {
                                        if (_showSimulateLiveButtons) {
                                          _simulateLiveFocus.requestFocus();
                                        } else {
                                          _viewerFocus.requestFocus();
                                        }
                                      },
                                      onKeyUp: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                      onKeyDown: () =>
                                          _viewerFocus.requestFocus(),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (_showSimulateLiveButtons) ...[
                                    SimulateLiveButton(
                                      focusNode: _simulateLiveFocus,
                                      onKeyUp: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                      onKeyLeft: () {
                                        if (showServerSkip) {
                                          _serverSkipFocus.requestFocus();
                                        } else {
                                          _focusActiveContent();
                                        }
                                      },
                                      onKeyRight: () => _simulateLiveTwoFocus
                                          .requestFocus(),
                                      onKeyDown: () =>
                                          _viewerFocus.requestFocus(),
                                    ),
                                    const SizedBox(width: 8),
                                    SimulateLiveButton(
                                      focusNode: _simulateLiveTwoFocus,
                                      eventCount: 2,
                                      icon: Icons.filter_2,
                                      onKeyUp: () => _focusViewerFavoritesBar(
                                        favChannels,
                                        channel,
                                      ),
                                      onKeyLeft: () =>
                                          _simulateLiveFocus.requestFocus(),
                                      onKeyRight: () =>
                                          _viewerFocus.requestFocus(),
                                      onKeyDown: () =>
                                          _viewerFocus.requestFocus(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
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

