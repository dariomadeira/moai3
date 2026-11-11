part of '../tv_friends_dialog.dart';

/// Buscar por apodo o código: la consulta, sus estados, el foco alrededor del buscador y el envío de la solicitud.
extension _TvFriendsSearchFlow on _TvFriendsDialogState {
  String _statusLabel(_SearchStatus status) => switch (status) {
    _SearchStatus.newUser => LocaleKeys.friends_search_status_new.tr(),
    _SearchStatus.friend => LocaleKeys.friends_search_status_friend.tr(),
    _SearchStatus.sent => LocaleKeys.friends_search_status_sent.tr(),
    _SearchStatus.incoming => LocaleKeys.friends_search_status_incoming.tr(),
  };

  /// Busca [raw] y, si trae algo, pasa el foco al primero. Todo lo que no
  /// es la lista (faltan letras, nada, falló) se muestra en su lugar.
  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.length < 2) {
      _update(() {
        _searchQuery = query;
        _searchResults = null;
        _searchNotice = LocaleKeys.friends_search_short;
      });
      _searchFocus.requestFocus();
      return;
    }

    _update(() {
      _searching = true;
      _searchNotice = null;
      _searchQuery = query;
    });
    try {
      final results = await context.read<WatchPartyProvider>().searchUsers(
        query,
      );
      if (!mounted) return;
      _update(() {
        _searchResults = results;
        _searchIndex = 0;
      });
      if (results.isNotEmpty) _focusSearchResults();
    } catch (e) {
      if (mounted) {
        _update(() {
          _searchResults = null;
          _searchNotice = LocaleKeys.friends_search_error;
        });
      }
    } finally {
      if (mounted) _update(() => _searching = false);
    }
  }

  /// La X: borra lo escrito y lo que se había encontrado.
  void _clearSearch() {
    _searchController.clear();
    _update(() {
      _searchQuery = '';
      _searchResults = null;
      _searchNotice = null;
      _searchIndex = 0;
    });
    _searchFocus.requestFocus();
  }

  /// ↓ desde el buscador o la X: al primer resultado, al aviso que ocupa su
  /// lugar o, si no hay nada, a Cerrar.
  void _focusBelowSearch() {
    if (_searchResults?.isNotEmpty ?? false) {
      _focusSearchResults(index: 0);
    } else if (_TvFriendsDialogState._focusable(_searchEmptyFocus)) {
      _searchEmptyFocus.requestFocus();
    } else {
      _closeFocus.requestFocus();
    }
  }

  /// ↑ desde Cerrar en Agregar y buscar: vuelve a lo que está arriba de
  /// Cerrar (el resultado donde había quedado, el aviso o el buscador), no
  /// al principio del panel.
  void _focusAboveClose() {
    if (_panel != TvFriendsDialog.addPanel) return _focusPanel();
    if (_searchResults?.isNotEmpty ?? false) {
      _focusSearchResults();
    } else if (_TvFriendsDialogState._focusable(_searchEmptyFocus)) {
      _searchEmptyFocus.requestFocus();
    } else {
      _searchFocus.requestFocus();
    }
  }

  /// Enfoca un resultado: [index] o donde había quedado. En el acto si la
  /// lista ya está armada; si no (recién llegó), en los cuadros siguientes.
  void _focusSearchResults({int? index}) {
    if (index != null) _searchIndex = index;
    _focus.request(() {
      final list = _searchListKey.currentState;
      if (list == null ||
          !_TvFriendsDialogState._focusable(_panelFocus[_panel])) {
        return false;
      }
      list.ensureVisible(_searchIndex);
      return true;
    }, immediate: true);
  }

  /// OK sobre un resultado: le manda la solicitud (o acepta la suya). Si ya
  /// es amigo o ya se la mandaste, sólo lo avisa.
  Future<void> _sendRequestTo(FriendInfo user) async {
    final watchParty = context.read<WatchPartyProvider>();
    final status = _statusOf(user, watchParty);
    if (status == _SearchStatus.friend || status == _SearchStatus.sent) {
      MoaiSnackBar.showInfo(context, message: _statusLabel(status));
      return;
    }
    final name = {'name': user.displayName};
    _update(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await watchParty.addFriend(user.userCode);
      if (mounted) {
        MoaiSnackBar.show(
          context,
          message: status == _SearchStatus.incoming
              ? LocaleKeys.friends_request_accepted.tr(namedArgs: name)
              : LocaleKeys.friends_request_sent.tr(namedArgs: name),
          icon: MoaiIcons.checkCircle,
        );
      }
    } catch (e) {
      if (mounted) {
        _update(() => _errorMessage = _TvFriendsDialogState._errorKey(e));
      }
    } finally {
      if (mounted) {
        _update(() => _isSubmitting = false);
        _focusSearchResults();
      }
    }
  }
}
