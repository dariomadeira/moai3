part of '../tv_friends_dialog.dart';

/// Lo que se hace con un amigo o una solicitud: agregar, aceptar, ver juntos, borrar y rechazar (con confirmación).
extension _TvFriendsActions on _TvFriendsDialogState {
  Future<void> _handleAddFriend([String? customCode]) async {
    final rawInput = (customCode ?? _codeController.text).trim().toUpperCase();

    // Sin código no se abre otro modal: se avisa y se vuelve al campo.
    if (rawInput.isEmpty) {
      _update(() {
        _errorMessage = LocaleKeys.friend_add_dialog_error_length;
      });
      _codeFocus.requestFocus();
      return;
    }

    _update(() {
      _isSubmitting = true;
      _addingByCode = true;
      _errorMessage = null;
    });

    try {
      final watchParty = context.read<WatchPartyProvider>();
      final added = await watchParty.addFriend(rawInput);
      _codeController.clear();
      if (mounted) {
        MoaiSnackBar.show(
          context,
          message: LocaleKeys.friends_request_sent.tr(
            namedArgs: {'name': added.displayName},
          ),
          icon: MoaiIcons.checkCircle,
        );
      }
    } catch (e) {
      if (mounted) {
        _update(() => _errorMessage = _TvFriendsDialogState._errorKey(e));
      }
    } finally {
      if (mounted) {
        _update(() {
          _isSubmitting = false;
          _addingByCode = false;
        });
      }
    }
  }

  Future<void> _handleAcceptRequest(FriendInfo request) async {
    _update(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final watchParty = context.read<WatchPartyProvider>();
      await watchParty.acceptFriendRequest(request);
    } catch (e) {
      if (mounted) {
        _update(() => _errorMessage = _TvFriendsDialogState._errorKey(e));
      }
    } finally {
      if (mounted) {
        _update(() => _isSubmitting = false);
        // La aceptada pasó a Amigos: el foco sigue en la lista.
        _requestsIndex = 0;
        _focusPanel();
      }
    }
  }

  /// Mirar juntos: cierra el modal y sintoniza el canal del amigo. Si no
  /// está conectado, no mira nada o el canal no está en la lista propia, lo
  /// avisa y el modal queda abierto.
  void _watchWithFriend(FriendInfo friend) {
    final channelName = friend.displayChannelName;
    final String? notice;
    Channel? channel;
    if (!friend.isOnline) {
      notice = LocaleKeys.friends_not_online.tr(
        namedArgs: {'name': friend.displayName},
      );
    } else if (channelName == null) {
      notice = LocaleKeys.home_friends_not_watching.tr(
        namedArgs: {'name': friend.displayName},
      );
    } else {
      final channels = context.read<ChannelProvider?>()?.allChannels;
      channel = HomeFriendsItem.channelOf(friend, channels ?? const []);
      notice = channel == null
          ? LocaleKeys.home_friends_channel_missing.tr(
              namedArgs: {'channel': channelName},
            )
          : null;
    }
    if (channel == null) {
      MoaiSnackBar.showInfo(context, message: notice!);
      return;
    }
    final onTune = widget.onTuneChannel;
    final provider = context.read<ChannelProvider>();
    Navigator.of(context).pop();
    if (onTune != null) {
      onTune(channel);
    } else {
      provider.selectChannel(channel);
    }
  }

  /// Confirmación destructiva (Cancelar enfocado, a la izquierda del botón
  /// rojo). `true` si confirmó.
  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) async {
    final confirmed = await showTvGeneralDialog<bool>(
      context: context,
      barrierLabel: 'FriendsConfirm',
      builder: (dialogContext) => _ConfirmDialog(
        icon: icon,
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmDeleteFriend(FriendInfo friend) async {
    final confirmed = await _confirm(
      icon: MoaiIcons.personRemove,
      title: LocaleKeys.friends_delete_confirm_title.tr(),
      subtitle: LocaleKeys.friends_delete_confirm_desc.tr(
        namedArgs: {'name': friend.displayName},
      ),
      confirmLabel: LocaleKeys.common_delete.tr(),
    );
    if (confirmed && mounted) {
      try {
        await context.read<WatchPartyProvider>().removeFriend(friend.deviceId);
      } catch (_) {
        // Silencioso
      }
    }
    if (mounted) _focusPanel();
  }

  /// Rechazar una solicitud: se borra su pedido. Si te vuelve a agregar,
  /// aparece otra vez.
  Future<void> _confirmRejectRequest(FriendInfo request) async {
    final confirmed = await confirmFriendReject(context, request);
    if (confirmed && mounted) {
      try {
        await context.read<WatchPartyProvider>().rejectFriendRequest(request);
      } catch (e) {
        if (mounted) {
          _update(
            () => _errorMessage = _TvFriendsDialogState._errorKey(
              e,
              fallback: LocaleKeys.friends_reject_error,
            ),
          );
        }
      }
    }
    if (mounted) {
      _requestsIndex = 0;
      _focusPanel();
    }
  }

  // --- Buscar por apodo y mandar la solicitud (panel Agregar y buscar) ---

  _SearchStatus _statusOf(FriendInfo user, WatchPartyProvider watchParty) {
    bool has(Iterable<FriendInfo> list) =>
        list.any((f) => f.deviceId == user.deviceId);
    if (has(watchParty.mutualFriends)) return _SearchStatus.friend;
    // Agregado pero no me agregó: ya le mandé la solicitud.
    if (has(watchParty.friends)) return _SearchStatus.sent;
    if (has(watchParty.friendRequests)) return _SearchStatus.incoming;
    return _SearchStatus.newUser;
  }
}
