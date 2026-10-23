import 'dart:async';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/features/channel_browser/widgets/category_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/channel_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/country_list_panel.dart';
import 'package:moai3/features/favorites/controllers/favorites_list_controller.dart';
import 'package:moai3/features/groups/controllers/groups_browser_controller.dart';
import 'package:moai3/features/groups/widgets/group_list_panel.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/controllers/tv_browser_session.dart';
import 'package:moai3/features/home/controllers/player_overlay_controller.dart';
import 'package:moai3/features/home/controllers/viewer_favorites_controller.dart';
import 'package:moai3/features/home/widgets/alphabet_jump_panel.dart';
import 'package:moai3/features/home/widgets/empty_viewer_panel.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/home/widgets/tv_viewer_panel.dart';
import 'package:moai3/features/home/widgets/tv_tab_bar.dart';
import 'package:moai3/features/home/widgets/tv_watch_party_header_bar.dart';
import 'package:moai3/features/home/widgets/viewer_favorites_bar.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/features/search/widgets/search_panel.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_panel_layout.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/clear_favorites_button.dart';
import 'package:moai3/widgets/buttons/create_group_button.dart';
import 'package:moai3/widgets/buttons/favorite_button.dart';
import 'package:moai3/widgets/buttons/server_skip_button.dart';
import 'package:moai3/widgets/feedback/debug_log_panel.dart';
import 'package:moai3/widgets/player/tv_player_overlay.dart';
import 'package:moai3/theme/moai_icons.dart';

part 'tv/home_tv_area_sync.dart';
part 'tv/home_tv_area_navigation.dart';
part 'tv/home_tv_area_explore.dart';
part 'tv/home_tv_area_groups.dart';
part 'tv/home_tv_area_layout.dart';

/// Área TV: Explorar / Grupos + viewer + player overlay + favoritos.
///
/// Contrato de foco = moaiSmart: Shortcuts globales en [HomeScreen];
/// → del rail llama [HomeTvAreaState.requestEntryFocus].
class HomeTvArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  /// Navegación que sobrevive al cambio de sección (la crea HomeScreen).
  final TvBrowserSession session;

  const HomeTvArea({
    super.key,
    required this.onExitLeft,
    required this.session,
  });

  @override
  State<HomeTvArea> createState() => HomeTvAreaState();
}

class HomeTvAreaState extends HomeAreaState<HomeTvArea>
    with WidgetsBindingObserver {
  TvBrowserSession get _session => widget.session;
  ChannelBrowserController get _browser => _session.browser;
  HomeSearchController get _search => _session.search;
  GroupsBrowserController get _groups => _session.groups;
  FavoritesListController get _favorites => _session.favorites;
  ViewerFavoritesController get _favoritesBar => _session.favoritesBar;
  final _playerOverlay = PlayerOverlayController();

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
  final _serverSkipFocus = FocusNode(debugLabel: 'tv_server_skip');
  final _logFocus = FocusNode(debugLabel: 'tv_log');
  final _watchPartyMicFocusNode = FocusNode(debugLabel: 'tv_header_mic');

  /// Un solo dueño de los pedidos de foco del área: el más nuevo gana.
  late final _focus = FocusRequester(isMounted: () => mounted);

  final _countryPanelKey = GlobalKey<CountryListPanelState>();
  final _categoryPanelKey = GlobalKey<CategoryListPanelState>();
  final _channelPanelKey = GlobalKey<ChannelListPanelState>();
  final _groupsChannelPanelKey = GlobalKey<ChannelListPanelState>();
  final _groupListPanelKey = GlobalKey<GroupListPanelState>();
  final _searchPanelKey = GlobalKey<SearchPanelState>();

  TvTab _tvTab = TvTab.explore;
  TvExplorePanel _activePanel = TvExplorePanel.channel;
  int _groupsPanelIndex = 0;
  bool _initialized = false;
  bool _lastShowTvLog = false;
  String? _lastPlayingChannelId;
  List<String> _lastChannelIds = [];
  List<String> _lastFavoriteIds = [];
  List<String> _lastGroupIds = [];
  List<Channel>? _lastChannelsRef;
  List<ChannelGroup>? _lastGroupsRef;
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
    if (!_session.isPopulated) _search.initialize();
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
    _tvTab = _session.tab ?? _tvSettingsProvider?.startupTvTab ?? TvTab.explore;

    final wp = context.read<WatchPartyProvider?>();
    if (wp != null) {
      _joinedNotificationsSubscription?.cancel();
      _joinedNotificationsSubscription = wp.joinedChannelNotificationsStream
          .listen((friendName) {
            // Aviso de segundo plano: no se muestra sobre un diálogo ni en Arcade.
            if (!mounted || ModalRouteTracker.instance.hasActiveModal) return;
            MoaiSnackBar.show(
              context,
              message: LocaleKeys.watch_party_friend_joined.tr(
                namedArgs: {'name': friendName},
              ),
              icon: MoaiIcons.person,
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
    _activePanel = TvPanelLayout.visible(
      _session.activePanel ?? TvExplorePanel.channel,
      _lastShowTvLog,
    );
    _groupsPanelIndex = _session.groupsPanelIndex;
    _lastChannelIds = _channelProvider!.allChannels.map((c) => c.id).toList();
    _lastFavoriteIds = List.from(_favoritesProvider!.favoriteChannelIds);
    _lastGroupIds = _channelProvider!.groups.map((g) => g.id).toList();
    _lastOverlapX = _tvSettingsProvider!.overlapPaddingX;
    _lastOverlapY = _tvSettingsProvider!.overlapPaddingY;

    if (_session.isPopulated) {
      // Volver a TV: conservar la selección y solo aplicar cambios del catálogo
      // o del bloqueo de adultos ocurridos mientras tanto.
      _browser.syncFromChannels(
        _channelProvider!.allChannels,
        isAdultUnlocked: _lastIsAdultUnlocked,
      );
    } else {
      _browser.initializeFromChannels(
        _channelProvider!.allChannels,
        initial: _channelProvider!.selectedChannel,
        isAdultUnlocked: _lastIsAdultUnlocked,
      );
    }
    _favorites.syncFrom(
      _channelProvider!.allChannels,
      _favoritesProvider!.favoriteChannelIds,
      isAdultUnlocked: _lastIsAdultUnlocked,
    );
    _favoritesBar.syncFrom(_favorites.favoriteChannels.length);
    _groups.syncFrom(
      _channelProvider!.groups,
      _channelProvider!.allChannels,
      _favoritesProvider!.favoriteChannelIds,
      isAdultUnlocked: _lastIsAdultUnlocked,
    );

    final initial = _channelProvider!.selectedChannel;
    if (initial != null) {
      _lastPlayingChannelId = initial.id;
      if (!_session.isPopulated) _groups.selectChannel(initial);
    }
    _session.tab = _tvTab;
  }

  /// `setState` para los `part` de esta área: las extensiones no pueden llamarlo
  /// directo porque es `@protected`.
  void _update(VoidCallback fn) => setState(fn);

  // Se queda en la clase: es un listener y necesita identidad estable.
  void _onStateChanged() => _syncWithProviders();

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _onPlayerOverlayChanged() {
    _rebuild();
    _schedulePlaceholderRectUpdate();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _schedulePlaceholderRectUpdate();
  }

  @override
  Widget build(BuildContext context) => _buildLayout(context);

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
    _session
      ..tab = _tvTab
      ..activePanel = _activePanel
      ..groupsPanelIndex = _groupsPanelIndex;
    _playerOverlay.dispose();
    _exploreTabFocus.dispose();
    _searchTabFocus.dispose();
    _groupsTabFocus.dispose();
    _viewerFocus.dispose();
    _favoriteBtnFocus.dispose();
    _createGroupFocus.dispose();
    _clearFavoritesFocus.dispose();
    _watchPartyMicFocusNode.dispose();
    _serverSkipFocus.dispose();
    _logFocus.dispose();
    super.dispose();
  }

  /// Público: lo llama el rail con → (Smart: `_returnFocusToActivePanel`).
  @override
  void requestEntryFocus() => returnFocusToActivePanel();

  void returnFocusToActivePanel() {
    if (_tvTab == TvTab.groups) {
      _focusGroupsPanel();
      return;
    }
    if (_tvTab == TvTab.search) {
      _focusSearchPanelEntry();
      return;
    }
    final showTvLog = context.read<TvSettingsProvider>().showTvLog;
    switch (TvPanelLayout.visible(_activePanel, showTvLog)) {
      case TvExplorePanel.log:
        _requestFocusWithRetry(_logFocus);
      case TvExplorePanel.country:
        _focusSelectedCountry();
      case TvExplorePanel.category:
        _focusSelectedCategory();
      case TvExplorePanel.channel:
        _focusSelectedChannel();
    }
  }

  /// Back del D-pad / sistema. `true` si se consumió (no salir de la app).
  @override
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
    if (_browser.alphabetPanel != null) {
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

  /// Permite a áreas externas (ej. Calendario) sintonizar un canal directamente.
  void selectChannel(Channel channel) => _selectChannel(channel);

  /// Solicita foco para el reproductor de TV desde áreas externas tras sintonizar.
  void requestViewerFocus() {
    if (mounted && _viewerFocus.canRequestFocus) {
      _viewerFocus.requestFocus();
    }
  }
}
