import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Diálogo para invitar a un amigo a jugar, con el listado TV de ventana fija.
class TvArcadeSelectFriendDialog extends StatefulWidget {
  final void Function(FriendInfo friend) onFriendSelected;

  const TvArcadeSelectFriendDialog({
    super.key,
    required this.onFriendSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(FriendInfo friend) onFriendSelected,
  }) {
    return showTvGeneralDialog(
      context: context,
      barrierLabel: 'TvArcadeSelectFriendDialog',
      builder: (dialogContext) => TvArcadeSelectFriendDialog(
        onFriendSelected: onFriendSelected,
      ),
    );
  }

  @override
  State<TvArcadeSelectFriendDialog> createState() =>
      _TvArcadeSelectFriendDialogState();
}

class _TvArcadeSelectFriendDialogState
    extends State<TvArcadeSelectFriendDialog> {
  static const int _windowSize = 4;
  static const double _itemExtent = 58;

  final FocusNode _closeFocus = FocusNode(debugLabel: 'select_friend_close');
  final FocusNode _manageFocus = FocusNode(debugLabel: 'select_friend_manage');
  final GlobalKey<TvWindowedListState<FriendInfo>> _listKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();

  List<FriendInfo> _sorted = const [];
  bool _askedEmptyFocus = false;

  @override
  void dispose() {
    _closeFocus.dispose();
    _manageFocus.dispose();
    super.dispose();
  }

  List<FriendInfo> _sortedFriends(List<FriendInfo> friends) {
    final sorted = friends.where((friend) => friend.isOnline).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (_sameFriends(_sorted, sorted)) return _sorted;
    _sorted = sorted;
    return _sorted;
  }

  bool _sameFriends(List<FriendInfo> a, List<FriendInfo> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].deviceId != b[i].deviceId ||
          a[i].isOnline != b[i].isOnline ||
          a[i].displayName != b[i].displayName) {
        return false;
      }
    }
    return true;
  }

  void _select(FriendInfo friend) {
    Navigator.of(context, rootNavigator: true).pop();
    widget.onFriendSelected(friend);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wp = context.watch<WatchPartyProvider?>();
    final sortedFriends = _sortedFriends(wp?.friends ?? const []);
    if (sortedFriends.isEmpty && !_askedEmptyFocus) {
      _askedEmptyFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _manageFocus.requestFocus();
      });
    }

    return TvDialog(
      width: 580,
      icon: MoaiIcons.personSearch,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: LocaleKeys.arcade_select_friend_title.tr(),
      subtitle: LocaleKeys.arcade_select_friend_subtitle.tr(),
      content: sortedFriends.isEmpty
          ? _EmptyFriends(manageFocus: _manageFocus)
          : _FriendWindow(
              listKey: _listKey,
              friends: sortedFriends,
              onSelect: _select,
              onFocusDownFromLast: _closeFocus.requestFocus,
            ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: LocaleKeys.common_close.tr(),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          onKeyUp: sortedFriends.isEmpty
              ? _manageFocus.requestFocus
              : () => _listKey.currentState?.ensureVisible(
                    sortedFriends.length - 1,
                  ),
        ),
      ],
    );
  }
}

class _FriendWindow extends StatelessWidget {
  final GlobalKey<TvWindowedListState<FriendInfo>> listKey;
  final List<FriendInfo> friends;
  final ValueChanged<FriendInfo> onSelect;
  final VoidCallback onFocusDownFromLast;

  const _FriendWindow({
    required this.listKey,
    required this.friends,
    required this.onSelect,
    required this.onFocusDownFromLast,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = friends.length.clamp(
      1,
      _TvArcadeSelectFriendDialogState._windowSize,
    );

    return SizedBox(
      height: rows * _TvArcadeSelectFriendDialogState._itemExtent,
      child: TvWindowedList<FriendInfo>(
        key: listKey,
        items: friends,
        windowSize: _TvArcadeSelectFriendDialogState._windowSize,
        itemExtent: _TvArcadeSelectFriendDialogState._itemExtent,
        showScrollDots: true,
        onFocusDownFromLast: onFocusDownFromLast,
        itemBuilder: (context, friend, focusNode, localIndex, globalIndex, onKeyUp, onKeyDown) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: TvTile(
              focusNode: focusNode,
              minHeight: 52,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              label: friend.displayName,
              description: LocaleKeys.friends_status_online.tr(),
              icon: MoaiIcons.person,
              onPressed: () => onSelect(friend),
              onKeyUp: onKeyUp,
              onKeyDown: onKeyDown,
              trailingBuilder: (context, isFocused) {
                return Icon(
                  MoaiIcons.gamepad,
                  size: 20,
                  color: isFocused
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFriends extends StatelessWidget {
  final FocusNode manageFocus;

  const _EmptyFriends({required this.manageFocus});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            MoaiIcons.friendsEmpty,
            size: 36,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.arcade_select_friend_empty.tr(),
            style: MoaiText.body(
              context,
              fontSize: 14,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TvDialogButton(
            focusNode: manageFocus,
            label: LocaleKeys.arcade_select_friend_manage.tr(),
            variant: TvDialogButtonVariant.primary,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              TvFriendsDialog.show(context);
            },
          ),
        ],
      ),
    );
  }
}
