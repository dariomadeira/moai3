import 'dart:math';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_add_friend_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';

String _formatFriendsCount(int total, int online) {
  if (total == 0) return '';
  if (total == 1) {
    return 'settings_tv_friends_count_single'.tr(
      namedArgs: {'count': '1', 'online': '$online'},
    );
  }
  return 'settings_tv_friends_count_plural'.tr(
    namedArgs: {'count': '$total', 'online': '$online'},
  );
}

/// Diálogo modal estándar de TV para la administración de amigos y solicitudes de amistad.
///
/// Utiliza el componente estándar [TvDialog] (ancho 800 dp) y [TvWindowedList] para ambas
/// columnas (amigos y solicitudes), garantizando tamaño fijo, navegación por ventanas
/// con puntos indicadores de scroll y cero desbordamientos (overflow) en Android TV.
class TvFriendsDialog extends StatefulWidget {
  const TvFriendsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvFriendsDialog',
      builder: (dialogContext) => const TvFriendsDialog(),
    );
  }

  @override
  State<TvFriendsDialog> createState() => _TvFriendsDialogState();
}

class _TvFriendsDialogState extends State<TvFriendsDialog> {
  static const int _windowSize = 3;
  static const double _itemExtent = 52.0;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode(debugLabel: 'friends_modal_code_input');
  final FocusNode _addFocus = FocusNode(debugLabel: 'friends_modal_add_btn');
  final FocusNode _closeFocus = FocusNode(debugLabel: 'friends_modal_close_btn');
  final GlobalKey<TvWindowedListState<FriendInfo>> _friendsListKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();
  final GlobalKey<TvWindowedListState<FriendInfo>> _requestsListKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();

  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<WatchPartyProvider>().loadFriends(showLoading: true);
        _codeFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    _addFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  Future<void> _handleAddFriend([String? customCode]) async {
    final rawInput = (customCode ?? _codeController.text).trim().toUpperCase();

    if (rawInput.isEmpty) {
      final added = await TvAddFriendDialog.show(context);
      if (added == true && mounted) {
        _codeController.clear();
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final watchParty = context.read<WatchPartyProvider>();
      await watchParty.addFriend(rawInput);
      _codeController.clear();
    } catch (e) {
      if (mounted) {
        final rawKey = e.toString().replaceFirst('Exception: ', '').trim();
        final localizedError = rawKey.tr();
        setState(() {
          _errorMessage = localizedError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleAcceptRequest(FriendInfo request) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final watchParty = context.read<WatchPartyProvider>();
      await watchParty.acceptFriendRequest(request);
    } catch (e) {
      if (mounted) {
        final rawKey = e.toString().replaceFirst('Exception: ', '').trim();
        final localizedError = rawKey.tr();
        setState(() {
          _errorMessage = localizedError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmDeleteFriend(FriendInfo friend) async {
    final confirmed = await showTvGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DeleteFriendConfirm',
      builder: (dialogContext) {
        final cancelFocus = FocusNode(debugLabel: 'delete_cancel');
        final deleteFocus = FocusNode(debugLabel: 'delete_confirm');
        return TvDialog(
          width: 460,
          icon: AppIcons.removeFriend,
          title: 'friends_delete_confirm_title'.tr(),
          subtitle: 'friends_delete_confirm_desc'.tr(
            namedArgs: {'name': friend.nickname ?? friend.userCode},
          ),
          actions: [
            TvDialogButton(
              label: 'common_cancel'.tr(),
              variant: TvDialogButtonVariant.neutral,
              focusNode: cancelFocus,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              onKeyRight: () => deleteFocus.requestFocus(),
            ),
            TvDialogButton(
              label: 'friends_delete_button'.tr(),
              variant: TvDialogButtonVariant.destructive,
              focusNode: deleteFocus,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              onKeyLeft: () => cancelFocus.requestFocus(),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<WatchPartyProvider>().removeFriend(friend.deviceId);
      } catch (_) {
        // Silencioso
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final watchParty = context.watch<WatchPartyProvider>();
    final friends = watchParty.friends;
    final requests = watchParty.friendRequests;
    final totalFriends = friends.length;
    final onlineFriends = watchParty.onlineFriendsCount;

    return TvDialog(
      width: 800,
      icon: AppIcons.friends,
      title: 'friends_screen_title'.tr(),
      subtitle: 'friends_screen_subtitle'.tr(),
      trailingHeader: totalFriends > 0
          ? Material(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  _formatFriendsCount(totalFriends, onlineFriends),
                  style: MoaiText.body(
                    context,
                    color: scheme.onTertiaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inputBar(context, scheme, watchParty),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Material(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      icon: AppIcons.error,
                      color: scheme.onErrorContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!.tr(),
                        style: MoaiText.body(
                          context,
                          color: scheme.onErrorContainer,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Distribución en 2 columnas con TvWindowedList
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna 1: Mis Amigos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader(
                      context,
                      scheme,
                      icon: AppIcons.friends,
                      title: 'friends_section_friends'.tr(),
                      badgeCount: totalFriends,
                    ),
                    const SizedBox(height: 6),
                    _buildFriendsContainer(
                      context,
                      scheme,
                      watchParty,
                      friends,
                      requests.length,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Columna 2: Solicitudes de Amistad
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader(
                      context,
                      scheme,
                      icon: AppIcons.addFriend,
                      title: 'friends_section_requests'.tr(),
                      badgeCount: requests.length,
                      isHighlighted: requests.isNotEmpty,
                    ),
                    const SizedBox(height: 6),
                    _buildRequestsContainer(
                      context,
                      scheme,
                      watchParty,
                      requests,
                      friends.length,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: 'common_close'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context).pop(),
          onKeyUp: () {
            if (friends.isNotEmpty) {
              _friendsListKey.currentState?.ensureVisible(
                friends.length - 1,
                requestFocus: true,
              );
            } else if (requests.isNotEmpty) {
              _requestsListKey.currentState?.ensureVisible(
                requests.length - 1,
                requestFocus: true,
              );
            } else {
              _addFocus.requestFocus();
            }
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    ColorScheme scheme, {
    required List<List<dynamic>> icon,
    required String title,
    required int badgeCount,
    bool isHighlighted = false,
  }) {
    return Row(
      children: [
        AppIcon(
          icon: icon,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TvTextField(
            controller: _codeController,
            focusNode: _codeFocus,
            label: 'friends_input_label'.tr(),
            hint: 'friends_input_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            doneLabel: 'friends_add_button'.tr(),
            leadingIcon: AppIcons.badge,
            maxLength: 10,
            onSubmitted: (val) => _handleAddFriend(val),
            onFocusRight: () => _addFocus.requestFocus(),
            onFocusDown: () {
              if (hasFriends) {
                _friendsListKey.currentState?.ensureVisible(0, requestFocus: true);
              } else if (hasRequests) {
                _requestsListKey.currentState?.ensureVisible(0, requestFocus: true);
              } else {
                _closeFocus.requestFocus();
              }
            },
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _addFocus,
          label: 'friends_add_button'.tr(),
          icon: AppIcons.addFriend,
          height: 52,
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
          onArrowLeft: () => _codeFocus.requestFocus(),
          onArrowDown: () {
            if (hasRequests) {
              _requestsListKey.currentState?.ensureVisible(0, requestFocus: true);
            } else if (hasFriends) {
              _friendsListKey.currentState?.ensureVisible(0, requestFocus: true);
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
    const listHeight = _windowSize * _itemExtent + 14.0;

    return Container(
      height: listHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: friends.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon: AppIcons.friends,
                    size: 24,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'friends_empty_title'.tr(),
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : TvWindowedList<FriendInfo>(
              key: _friendsListKey,
              items: friends,
              windowSize: _windowSize,
              itemExtent: _itemExtent,
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
                        requestFocus: true,
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
    const listHeight = _windowSize * _itemExtent + 14.0;

    return Container(
      height: listHeight,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: requests.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    icon: AppIcons.email,
                    size: 24,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'friends_requests_empty'.tr(),
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : TvWindowedList<FriendInfo>(
              key: _requestsListKey,
              items: requests,
              windowSize: _windowSize,
              itemExtent: _itemExtent,
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
                        requestFocus: true,
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

class _FriendTile extends StatefulWidget {
  final FriendInfo friend;
  final FocusNode focusNode;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyRightAcross;
  final VoidCallback onDelete;

  const _FriendTile({
    super.key,
    required this.friend,
    required this.focusNode,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyRightAcross,
    required this.onDelete,
  });

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _FriendTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;

    final bg = isFocused
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    final hasNickname = widget.friend.nickname != null &&
        widget.friend.nickname!.trim().isNotEmpty;
    final displayName =
        hasNickname ? widget.friend.nickname! : widget.friend.userCode;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp) {
            widget.onKeyUp();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            widget.onKeyDown();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            widget.onKeyRightAcross();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            widget.onDelete();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onDelete,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: AppIcon(
                      icon: AppIcons.person,
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: titleColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            widget.friend.userCode,
                            style: MoaiText.body(
                              context,
                              color: descColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? scheme.onPrimary.withValues(alpha: 0.22)
                                  : widget.friend.isOnline
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4.5,
                                  height: 4.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: widget.friend.isOnline
                                        ? Colors.greenAccent.shade400
                                        : scheme.outlineVariant,
                                  ),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  widget.friend.isOnline
                                      ? 'friends_status_online'.tr()
                                      : 'friends_status_offline'.tr(),
                                  style: MoaiText.body(
                                    context,
                                    color: isFocused
                                        ? scheme.onPrimary
                                        : widget.friend.isOnline
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurfaceVariant,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.friend.displayChannelName != null) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? scheme.onPrimary.withValues(alpha: 0.22)
                                      : scheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AppIcon(
                                      icon: AppIcons.tv,
                                      size: 8.5,
                                      color: isFocused
                                          ? scheme.onPrimary
                                          : scheme.onTertiaryContainer,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        widget.friend.displayChannelName!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MoaiText.body(
                                          context,
                                          color: isFocused
                                              ? scheme.onPrimary
                                              : scheme.onTertiaryContainer,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Botón de eliminar con estilo idéntico al Administrador de Extensiones
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? scheme.primaryContainer
                        : scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppIcon(
                    icon: AppIcons.delete,
                    size: 15,
                    color: isFocused
                        ? scheme.onPrimaryContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatefulWidget {
  final FriendInfo request;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback onKeyLeftAcross;
  final VoidCallback onAccept;

  const _RequestTile({
    super.key,
    required this.request,
    required this.focusNode,
    required this.isLoading,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyLeftAcross,
    required this.onAccept,
  });

  @override
  State<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends State<_RequestTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant _RequestTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;

    final bg = isFocused
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.tertiaryContainer;
    final iconColor = isFocused
        ? scheme.onPrimary
        : scheme.onTertiaryContainer;

    final hasNickname = widget.request.nickname != null &&
        widget.request.nickname!.trim().isNotEmpty;
    final displayName =
        hasNickname ? widget.request.nickname! : widget.request.userCode;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp) {
            widget.onKeyUp();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            widget.onKeyDown();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onKeyLeftAcross();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            if (!widget.isLoading) {
              widget.onAccept();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.isLoading ? null : widget.onAccept,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: AppIcon(
                      icon: AppIcons.addFriend,
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: titleColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.request.userCode,
                        style: MoaiText.body(
                          context,
                          color: descColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Botón de Aceptar compacto con estilo de Administrador de Extensiones
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFocused
                        ? scheme.primaryContainer
                        : scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        icon: AppIcons.check,
                        size: 12,
                        color: isFocused
                            ? scheme.onPrimaryContainer
                            : scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'friends_accept_button'.tr(),
                        style: MoaiText.body(
                          context,
                          color: isFocused
                              ? scheme.onPrimaryContainer
                              : scheme.onSecondaryContainer,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
