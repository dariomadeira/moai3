part of '../home_tv_area.dart';

/// Sincronización del área TV con los providers de canales, ajustes y favoritos.
extension _TvAreaSync on HomeTvAreaState {
  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
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

  void _requestInitialPlayerFocus() => _focus.request(() {
    if (!_playerOverlay.hasValidRect) return false;
    _viewerFocus.requestFocus();
    _playerOverlay.markInitialFocusDone();
    return true;
  }, maxFrames: 30);

  void _syncWithProviders() {
    if (!mounted) return;
    final tvSettings =
        _tvSettingsProvider ?? context.read<TvSettingsProvider>();
    final channelProv = _channelProvider ?? context.read<ChannelProvider>();
    final favProv = _favoritesProvider ?? context.read<FavoritesProvider>();

    final showTvLog = tvSettings.showTvLog;
    if (showTvLog != _lastShowTvLog) {
      _update(() {
        _lastShowTvLog = showTvLog;
        _activePanel = TvPanelLayout.visible(_activePanel, showTvLog);
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
    final groups = channelProv.groups;
    // Los repositorios crean una lista nueva solo al cambiar los datos: si la
    // referencia es la misma se evita recorrer todo el catálogo (SPEC-50 §6.1).
    final channelIds = identical(channels, _lastChannelsRef)
        ? _lastChannelIds
        : channels.map((c) => c.id).toList();
    final groupIds = identical(groups, _lastGroupsRef)
        ? _lastGroupIds
        : groups.map((g) => g.id).toList();
    _lastChannelsRef = channels;
    _lastGroupsRef = groups;
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

    if (channelsChanged ||
        favIdsChanged ||
        groupsChanged ||
        adultUnlockedChanged) {
      if (favIdsChanged) {
        _lastFavoriteIds = List.from(favIds);
      }
      if (groupsChanged) {
        _lastGroupIds = List.from(groupIds);
      }
      _favorites.syncFrom(channels, favIds, isAdultUnlocked: isAdultUnlocked);
      favProv.sanitizeAdultFavorites(channels);
      _favoritesBar.syncFrom(_favorites.favoriteChannels.length);
      _groups.syncFrom(
        channelProv.groups,
        channels,
        favIds,
        isAdultUnlocked: isAdultUnlocked,
      );
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

    if (_playerOverlay.shouldRequestInitialFocus(
      channelProv.isLoadingChannels,
    )) {
      _requestInitialPlayerFocus();
    }
  }
}
