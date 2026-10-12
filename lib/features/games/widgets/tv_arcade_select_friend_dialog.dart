import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:provider/provider.dart';

/// Diálogo modal estándar de TV para seleccionar un amigo conectado e invitarlo a jugar.
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
      barrierDismissible: true,
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
  final FocusNode _closeFocus = FocusNode(debugLabel: 'select_friend_close');
  final List<FocusNode> _itemFocusNodes = [];

  @override
  void dispose() {
    _closeFocus.dispose();
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncFocusNodes(int count) {
    while (_itemFocusNodes.length < count) {
      _itemFocusNodes.add(
        FocusNode(debugLabel: 'friend_item_${_itemFocusNodes.length}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wp = context.watch<WatchPartyProvider?>();
    final friends = wp?.friends ?? [];

    // Priorizar amigos en línea arriba
    final sortedFriends = List<FriendInfo>.from(friends)
      ..sort((a, b) {
        if (a.isOnline && !b.isOnline) return -1;
        if (!a.isOnline && b.isOnline) return 1;
        return a.displayName.compareTo(b.displayName);
      });

    _syncFocusNodes(sortedFriends.length);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _itemFocusNodes.isNotEmpty && !_itemFocusNodes.any((f) => f.hasFocus) && !_closeFocus.hasFocus) {
        _itemFocusNodes.first.requestFocus();
      }
    });

    return TvDialog(
      width: 520,
      icon: Icons.person_search_rounded,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: 'arcade_select_friend_title'.tr(),
      subtitle: 'arcade_select_friend_subtitle'.tr(),
      content: sortedFriends.isEmpty
          ? Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.group_off_outlined,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'arcade_select_friend_empty'.tr(),
                    style: MoaiText.body(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TvDialogButton(
                    focusNode: _closeFocus,
                    label: 'arcade_select_friend_manage'.tr(),
                    variant: TvDialogButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      TvFriendsDialog.show(context);
                    },
                  ),
                ],
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sortedFriends.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final friend = sortedFriends[index];
                  final focusNode = _itemFocusNodes[index];
                  return _FriendTile(
                    friend: friend,
                    focusNode: focusNode,
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).pop();
                      widget.onFriendSelected(friend);
                    },
                  );
                },
              ),
            ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: 'arcade_select_friend_close'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
    );
  }
}

class _FriendTile extends StatefulWidget {
  final FriendInfo friend;
  final FocusNode focusNode;
  final VoidCallback onTap;

  const _FriendTile({
    required this.friend,
    required this.focusNode,
    required this.onTap,
  });

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOnline = widget.friend.isOnline;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _isFocused
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.2),
            width: _isFocused ? 1.8 : 1.0,
          ),
        ),
        child: ListTile(
          onTap: widget.onTap,
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.surfaceContainerHighest,
                child: Text(
                  widget.friend.displayName.isNotEmpty
                      ? widget.friend.displayName[0].toUpperCase()
                      : '?',
                  style: MoaiText.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.greenAccent.shade700 : Colors.grey.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            widget.friend.displayName,
            style: MoaiText.body(
              context,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            isOnline
                ? 'friends_status_online'.tr()
                : 'friends_status_offline'.tr(),
            style: MoaiText.body(
              context,
              fontSize: 12,
              color: isOnline ? Colors.greenAccent.shade400 : scheme.onSurfaceVariant,
            ),
          ),
          trailing: Icon(
            Icons.sports_esports_rounded,
            size: 20,
            color: _isFocused ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
