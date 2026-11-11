part of '../tv_friends_dialog.dart';

/// Pestañas y contenido de los tres paneles.
extension _TvFriendsSections on _TvFriendsDialogState {
  static const double _panelPadding = 14;

  /// Pestaña del acordeón (como las de Ajustes) con el contador naranja del
  /// rail arriba si hay algo que contar.
  Widget _panelTab(String title, IconData icon, int badge) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned.fill(
          child: CollapsedPanelTabPreview(title: title, icon: icon),
        ),
        if (badge > 0)
          Positioned(top: 10, child: MoaiCountBadge(count: badge, size: 22)),
      ],
    );
  }

  /// Panel vacío: el [TvEmptyStateCard] de las demás listas. Enfocable; las
  /// flechas las maneja el Focus del panel ([_onPanelKey]).
  Widget _emptyState(
    int panel, {
    required IconData icon,
    required String text,
  }) {
    return Center(
      child: TvEmptyStateCard(
        focusNode: _emptyFocus[panel],
        icon: icon,
        message: text,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
    );
  }

  Widget _friendsPanel(
    BuildContext context,
    ColorScheme scheme,
    List<FriendInfo> friends,
  ) {
    final watchParty = context.read<WatchPartyProvider>();
    final channels =
        context.read<ChannelProvider?>()?.allChannels ?? const <Channel>[];
    return Padding(
      padding: const EdgeInsets.all(_panelPadding),
      child: friends.isEmpty
          ? _emptyState(
              TvFriendsDialog.friendsPanel,
              icon: MoaiIcons.friendsEmpty,
              text: LocaleKeys.friends_empty_title.tr(),
            )
          : TvWindowedList<FriendInfo>(
              key: _friendsListKey,
              items: friends,
              windowSize: _TvFriendsDialogState._windowSize,
              itemExtent: _TvFriendsDialogState._friendExtent,
              initialGlobalIndex: _friendsIndex.clamp(0, friends.length - 1),
              showScrollDots: true,
              onFocusedGlobalIndex: (i) => _friendsIndex = i,
              itemBuilder:
                  (
                    context,
                    friend,
                    focusNode,
                    local,
                    global,
                    onKeyUp,
                    onKeyDown,
                  ) {
                    return _FriendTile(
                      key: ValueKey(friend.deviceId),
                      friend: friend,
                      focusNode: focusNode,
                      withMe:
                          friend.isOnline &&
                          friend.isWatchingSameChannel(
                            watchParty.currentChannelId,
                            watchParty.currentChannelName,
                          ),
                      logoUrl: HomeFriendsItem.channelOf(
                        friend,
                        channels,
                      )?.logoUrl.trim(),
                      onKeyUp: onKeyUp,
                      onKeyDown: () {
                        if (global >= friends.length - 1) {
                          _closeFocus.requestFocus();
                        } else {
                          onKeyDown();
                        }
                      },
                      onKeyRightAcross: () =>
                          _selectPanel(TvFriendsDialog.requestsPanel),
                      onWatch: () => _watchWithFriend(friend),
                      onDelete: () => _confirmDeleteFriend(friend),
                    );
                  },
            ),
    );
  }

  Widget _requestsPanel(
    BuildContext context,
    ColorScheme scheme,
    List<FriendInfo> requests,
  ) {
    return Padding(
      padding: const EdgeInsets.all(_panelPadding),
      child: requests.isEmpty
          ? _emptyState(
              TvFriendsDialog.requestsPanel,
              icon: MoaiIcons.friendRequests,
              text: LocaleKeys.friends_requests_empty.tr(),
            )
          : TvWindowedList<FriendInfo>(
              key: _requestsListKey,
              items: requests,
              windowSize: _TvFriendsDialogState._windowSize,
              itemExtent: _TvFriendsDialogState._friendExtent,
              initialGlobalIndex: _requestsIndex.clamp(0, requests.length - 1),
              showScrollDots: true,
              onFocusedGlobalIndex: (i) => _requestsIndex = i,
              itemBuilder:
                  (
                    context,
                    request,
                    focusNode,
                    local,
                    global,
                    onKeyUp,
                    onKeyDown,
                  ) {
                    return _RequestTile(
                      key: ValueKey(request.deviceId),
                      request: request,
                      subtitle: LocaleKeys.friends_request_subtitle.tr(),
                      focusNode: focusNode,
                      isLoading: _isSubmitting,
                      onKeyUp: onKeyUp,
                      onKeyDown: () {
                        if (global >= requests.length - 1) {
                          _closeFocus.requestFocus();
                        } else {
                          onKeyDown();
                        }
                      },
                      onKeyLeftAcross: () =>
                          _selectPanel(TvFriendsDialog.friendsPanel),
                      onAccept: () => _handleAcceptRequest(request),
                      onReject: () => _confirmRejectRequest(request),
                    );
                  },
            ),
    );
  }

  /// Agregar y buscar: arriba el código y Agregar; abajo buscar por apodo
  /// (el campo abre el teclado y al confirmar busca) y lo que trajo.
  Widget _addPanel(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
  ) {
    final results = _searchResults;
    return Padding(
      padding: const EdgeInsets.all(_panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TvTextField(
                  controller: _codeController,
                  focusNode: _codeFocus,
                  label: LocaleKeys.friends_input_label.tr(),
                  hint: LocaleKeys.friends_input_hint.tr(),
                  doneLabel: LocaleKeys.friends_add_button.tr(),
                  leadingIcon: MoaiIcons.keyboard,
                  maxLength: 10,
                  dense: true,
                  onSubmitted: _handleAddFriend,
                  onFocusLeft: () =>
                      _selectPanel(TvFriendsDialog.requestsPanel),
                  onFocusRight: _addFocus.requestFocus,
                  onFocusDown: _searchFocus.requestFocus,
                ),
              ),
              const SizedBox(width: 10),
              TvFocusButton(
                focusNode: _addFocus,
                label: LocaleKeys.friends_add_button.tr(),
                icon: MoaiIcons.friendAddButton,
                height: 52,
                radius: 26,
                variant: TvButtonVariant.tonal,
                loading: _addingByCode,
                // Usa siempre el código del campo (vacío: avisa y vuelve al
                // campo).
                onPressed: _isSubmitting ? null : _handleAddFriend,
                onArrowLeft: _codeFocus.requestFocus,
                onArrowDown: () =>
                    (_canClearSearch ? _clearFocus : _searchFocus)
                        .requestFocus(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Buscar por apodo y, si hay algo para borrar, la X al lado.
          ListenableBuilder(
            listenable: _searchController,
            builder: (context, _) => Row(
              children: [
                Expanded(
                  child: TvTextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    label: LocaleKeys.friends_search_label.tr(),
                    hint: LocaleKeys.friends_search_hint.tr(),
                    doneLabel: LocaleKeys.friends_search_button.tr(),
                    leadingIcon: MoaiIcons.search,
                    dense: true,
                    onSubmitted: _search,
                    onFocusUp: _codeFocus.requestFocus,
                    onFocusLeft: () =>
                        _selectPanel(TvFriendsDialog.requestsPanel),
                    onFocusRight: () {
                      if (_canClearSearch) _clearFocus.requestFocus();
                    },
                    onFocusDown: _focusBelowSearch,
                  ),
                ),
                if (_canClearSearch) ...[
                  const SizedBox(width: 10),
                  // Sólo ícono (label vacío): un botón redondo.
                  TvFocusButton(
                    focusNode: _clearFocus,
                    label: '',
                    icon: MoaiIcons.close,
                    height: 52,
                    radius: 26,
                    variant: TvButtonVariant.tonal,
                    onPressed: _clearSearch,
                    onArrowLeft: _searchFocus.requestFocus,
                    onArrowUp: _addFocus.requestFocus,
                    onArrowDown: _focusBelowSearch,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _searchArea(context, scheme, watchParty, results)),
        ],
      ),
    );
  }

  /// El lugar de los resultados: buscando, el aviso (faltan letras, nada,
  /// falló) como estado vacío, o la lista (OK manda la solicitud; ↑ desde
  /// el primero vuelve al buscador).
  Widget _searchArea(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
    List<FriendInfo>? results,
  ) {
    if (_searching) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final notice = _searchNotice;
    final String? emptyText = notice != null
        ? notice.tr()
        : results != null && results.isEmpty
        ? LocaleKeys.friends_search_empty.tr(namedArgs: {'query': _searchQuery})
        : null;
    if (emptyText != null) {
      return Center(
        child: TvEmptyStateCard(
          focusNode: _searchEmptyFocus,
          icon: notice == LocaleKeys.friends_search_error
              ? MoaiIcons.error
              : MoaiIcons.search,
          message: emptyText,
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          onFocusUp: _searchFocus.requestFocus,
          onFocusDown: _closeFocus.requestFocus,
          onFocusLeft: () => _selectPanel(TvFriendsDialog.requestsPanel),
        ),
      );
    }
    if (results == null) return const SizedBox.shrink();
    return TvWindowedList<FriendInfo>(
      key: _searchListKey,
      items: results,
      windowSize: _TvFriendsDialogState._searchWindowSize,
      itemExtent: _TvFriendsDialogState._friendExtent,
      initialGlobalIndex: _searchIndex.clamp(0, results.length - 1),
      showScrollDots: true,
      onFocusedGlobalIndex: (i) => _searchIndex = i,
      itemBuilder:
          (context, user, focusNode, local, global, onKeyUp, onKeyDown) {
            return _RequestTile(
              key: ValueKey('search_${user.deviceId}'),
              request: user,
              subtitle: _statusLabel(_statusOf(user, watchParty)),
              focusNode: focusNode,
              isLoading: _isSubmitting,
              onKeyUp: global == 0 ? _searchFocus.requestFocus : onKeyUp,
              onKeyDown: global >= results.length - 1
                  ? _closeFocus.requestFocus
                  : onKeyDown,
              onKeyLeftAcross: () =>
                  _selectPanel(TvFriendsDialog.requestsPanel),
              onAccept: () => _sendRequestTo(user),
            );
          },
    );
  }

  /// Aviso de error: etiqueta de cristal teñida de rojo.
  Widget _errorBanner(BuildContext context, ColorScheme scheme) {
    const color = MoaiStatusTag.liveColor;
    return DecoratedBox(
      decoration: moaiGlassTagDecoration(scheme, radius: 12, tint: color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(MoaiIcons.error, color: color, size: MoaiIconSizes.sm),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!.tr(),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurface,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
