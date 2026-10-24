part of '../tv_friends_dialog.dart';

/// Cabeceras, barra de código y columnas de amigos y solicitudes.
extension _TvFriendsSections on _TvFriendsDialogState {
  Widget _sectionHeader(
    BuildContext context,
    ColorScheme scheme, {
    required IconData icon,
    required String title,
    required int badgeCount,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isHighlighted ? scheme.primary : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: MoaiText.body(
            context,
            color: scheme.onSurface,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: isHighlighted
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$badgeCount',
            style: MoaiText.body(
              context,
              color: isHighlighted
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputBar(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
  ) {
    final hasFriends = watchParty.friends.isNotEmpty;
    final hasRequests = watchParty.friendRequests.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _codeController,
            focusNode: _codeFocus,
            label: LocaleKeys.friends_input_label.tr(),
            hint: LocaleKeys.friends_input_hint.tr(),
            doneLabel: LocaleKeys.friends_add_button.tr(),
            leadingIcon: MoaiIcons.nickname,
            maxLength: 10,
            onSubmitted: _handleAddFriend,
            onFocusRight: _addFocus.requestFocus,
            onFocusDown: () {
              if (hasFriends) {
                _friendsListKey.currentState?.ensureVisible(0);
              } else if (hasRequests) {
                _requestsListKey.currentState?.ensureVisible(0);
              } else {
                _closeFocus.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _addFocus,
          label: LocaleKeys.friends_add_button.tr(),
          icon: MoaiIcons.personAdd,
          height: 60,
          radius: 30,
          variant: TvButtonVariant.tonal,
          loading: _isSubmitting,
          onPressed: _isSubmitting
              ? null
              : () {
                  final text = _codeController.text.trim();
                  if (text.isEmpty) {
                    TvAddFriendDialog.show(context).then((added) {
                      if (added == true && mounted) {
                        _codeController.clear();
                      }
                    });
                  } else {
                    _handleAddFriend();
                  }
                },
          onArrowLeft: _codeFocus.requestFocus,
          onArrowDown: () {
            if (hasRequests) {
              _requestsListKey.currentState?.ensureVisible(0);
            } else if (hasFriends) {
              _friendsListKey.currentState?.ensureVisible(0);
            } else {
              _closeFocus.requestFocus();
            }
          },
        ),
      ],
    );
  }

  Widget _buildFriendsContainer(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
    List<FriendInfo> friends,
    int requestsCount,
  ) {
    const listHeight = _TvFriendsDialogState._windowSize * _TvFriendsDialogState._itemExtent + 14.0;
    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

    return Container(
      height: listHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [baseColor, baseColor, endColor],
          stops: const [0.0, 0.62, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: friends.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MoaiIcons.friendsEmpty,
                    size: 24,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocaleKeys.friends_empty_title.tr(),
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            )
          : TvWindowedList<FriendInfo>(
              key: _friendsListKey,
              items: friends,
              windowSize: _TvFriendsDialogState._windowSize,
              itemExtent: _TvFriendsDialogState._itemExtent,
              showScrollDots: true,
              itemBuilder: (context, friend, focusNode, local, global, onKeyUp, onKeyDown) {
                return _FriendTile(
                  key: ValueKey(friend.deviceId),
                  friend: friend,
                  focusNode: focusNode,
                  onKeyUp: () {
                    if (global == 0) {
                      _codeFocus.requestFocus();
                    } else {
                      onKeyUp();
                    }
                  },
                  onKeyDown: () {
                    if (global >= friends.length - 1) {
                      _closeFocus.requestFocus();
                    } else {
                      onKeyDown();
                    }
                  },
                  onKeyRightAcross: () {
                    if (requestsCount > 0) {
                      final targetIndex = min(global, requestsCount - 1);
                      _requestsListKey.currentState?.ensureVisible(
                        targetIndex,
                      );
                    }
                  },
                  onDelete: () => _confirmDeleteFriend(friend),
                );
              },
            ),
    );
  }

  Widget _buildRequestsContainer(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
    List<FriendInfo> requests,
    int friendsCount,
  ) {
    const listHeight = _TvFriendsDialogState._windowSize * _TvFriendsDialogState._itemExtent + 14.0;
    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

    return Container(
      height: listHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [baseColor, baseColor, endColor],
          stops: const [0.0, 0.62, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    MoaiIcons.friendRequests,
                    size: 24,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocaleKeys.friends_requests_empty.tr(),
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            )
          : TvWindowedList<FriendInfo>(
              key: _requestsListKey,
              items: requests,
              windowSize: _TvFriendsDialogState._windowSize,
              itemExtent: _TvFriendsDialogState._itemExtent,
              showScrollDots: true,
              itemBuilder: (context, request, focusNode, local, global, onKeyUp, onKeyDown) {
                return _RequestTile(
                  key: ValueKey(request.deviceId),
                  request: request,
                  focusNode: focusNode,
                  isLoading: _isSubmitting,
                  onKeyUp: () {
                    if (global == 0) {
                      _addFocus.requestFocus();
                    } else {
                      onKeyUp();
                    }
                  },
                  onKeyDown: () {
                    if (global >= requests.length - 1) {
                      _closeFocus.requestFocus();
                    } else {
                      onKeyDown();
                    }
                  },
                  onKeyLeftAcross: () {
                    if (friendsCount > 0) {
                      final targetIndex = min(global, friendsCount - 1);
                      _friendsListKey.currentState?.ensureVisible(
                        targetIndex,
                      );
                    } else {
                      _codeFocus.requestFocus();
                    }
                  },
                  onAccept: () => _handleAcceptRequest(request),
                );
              },
            ),
    );
  }
}
