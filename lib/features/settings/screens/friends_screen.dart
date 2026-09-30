import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/dialogs/tv_add_friend_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
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

/// Pantalla de administración de amigos "Mis Amigos".
///
/// Comparte el mismo lenguaje visual, componentes y comportamiento de navegación TV
/// que el Administrador de Extensiones ([SourcesScreen]), adaptado a una sola columna.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FriendsScreen(),
      ),
    );
  }

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _backFocus = FocusNode(debugLabel: 'friends_back');
  final FocusNode _codeFocus = FocusNode(debugLabel: 'friends_code_input');
  final FocusNode _addFocus = FocusNode(debugLabel: 'friends_add_btn');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'friends_empty');
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _tileFocuses = [];

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
    _backFocus.dispose();
    _codeFocus.dispose();
    _addFocus.dispose();
    _emptyFocusNode.dispose();
    _scrollController.dispose();
    for (final node in _tileFocuses) {
      node.dispose();
    }
    super.dispose();
  }

  void _resyncFocus(int count) {
    while (_tileFocuses.length < count) {
      _tileFocuses.add(FocusNode(debugLabel: 'friend_tile_${_tileFocuses.length}'));
    }
  }

  Future<void> _handleAddFriend([String? customCode]) async {
    final rawInput = (customCode ?? _codeController.text).trim().toUpperCase();

    if (rawInput.isEmpty) {
      // Si el campo está vacío, abrimos el modal interactivo de agregar amigo
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
      if (mounted) {
        MoaiSnackBar.show(
          context,
          message: 'friend_add_dialog_success'.tr(),
          icon: Icons.check_circle_outline,
        );
      }
    } catch (e) {
      if (mounted) {
        final rawKey = e.toString().replaceFirst('Exception: ', '').trim();
        final localizedError = rawKey.tr();
        setState(() {
          _errorMessage = localizedError;
        });
        MoaiSnackBar.show(
          context,
          message: localizedError,
          icon: Icons.error_outline,
        );
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
          icon: Icons.person_remove_outlined,
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
        if (mounted) {
          MoaiSnackBar.show(
            context,
            message: 'friends_delete_success'.tr(),
            icon: Icons.check,
          );
        }
      } catch (e) {
        if (mounted) {
          MoaiSnackBar.show(
            context,
            message: 'friends_delete_error'.tr(),
            icon: Icons.error_outline,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final watchParty = context.watch<WatchPartyProvider>();
    final friends = watchParty.friends;
    final totalFriends = friends.length;
    final onlineFriends = watchParty.onlineFriendsCount;

    _resyncFocus(totalFriends);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, scheme, totalFriends, onlineFriends),
                const SizedBox(height: 18),
                _inputBar(context, scheme, watchParty),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: scheme.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!.tr(),
                              style: MoaiText.body(
                                context,
                                color: scheme.onErrorContainer,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: _buildSingleColumnLayout(
                    context,
                    scheme,
                    watchParty,
                    friends,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    ColorScheme scheme,
    int totalFriends,
    int onlineFriends,
  ) {
    return Row(
      children: [
        _BackButton(
          focusNode: _backFocus,
          onPressed: () => Navigator.of(context).pop(),
          onFocusRight: () => _codeFocus.requestFocus(),
          onFocusDown: () => _codeFocus.requestFocus(),
        ),
        const SizedBox(width: 14),
        Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.people_alt_rounded,
              color: scheme.onPrimaryContainer,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'friends_screen_title'.tr(),
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'friends_screen_subtitle'.tr(),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (totalFriends > 0) ...[
          const SizedBox(width: 12),
          Material(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                _formatFriendsCount(totalFriends, onlineFriends),
                style: MoaiText.body(
                  context,
                  color: scheme.onTertiaryContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _inputBar(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
  ) {
    final hasFriends = watchParty.friends.isNotEmpty;

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
            leadingIcon: Icons.badge_outlined,
            maxLength: 10,
            onSubmitted: (val) => _handleAddFriend(val),
            onFocusLeft: () => _backFocus.requestFocus(),
            onFocusRight: () => _addFocus.requestFocus(),
            onFocusUp: () => _backFocus.requestFocus(),
            onFocusDown: hasFriends
                ? () => _tileFocuses.first.requestFocus()
                : () => _emptyFocusNode.requestFocus(),
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _addFocus,
          label: 'friends_add_button'.tr(),
          icon: Symbols.person_add,
          height: 60,
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
          onArrowUp: () => _backFocus.requestFocus(),
          onArrowDown: hasFriends
              ? () => _tileFocuses.first.requestFocus()
              : () => _emptyFocusNode.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildSingleColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    WatchPartyProvider watchParty,
    List<FriendInfo> friends,
  ) {
    if (watchParty.isLoading && friends.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: scheme.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (friends.isEmpty) {
      return TvEmptyStateCard(
        focusNode: _emptyFocusNode,
        icon: Icons.group_off_outlined,
        message: 'friends_empty_title'.tr(),
        onFocusUp: () => _addFocus.requestFocus(),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: friends.length,
        itemBuilder: (context, i) {
          final friend = friends[i];
          final tileFocus = _tileFocuses[i];
          final isFirst = i == 0;
          final isLast = i == friends.length - 1;

          return _FriendTile(
            key: ValueKey(friend.deviceId),
            friend: friend,
            focusNode: tileFocus,
            onKeyUp: () {
              if (isFirst) {
                _codeFocus.requestFocus();
              } else {
                _tileFocuses[i - 1].requestFocus();
              }
            },
            onKeyDown: () {
              if (!isLast) {
                _tileFocuses[i + 1].requestFocus();
              }
            },
            onDelete: () => _confirmDeleteFriend(friend),
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
  final VoidCallback onDelete;

  const _FriendTile({
    super.key,
    required this.friend,
    required this.focusNode,
    required this.onKeyUp,
    required this.onKeyDown,
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
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) {
      setState(() {});
      if (widget.focusNode.hasFocus) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused = widget.focusNode.hasFocus;

    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Material(
              color: iconBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        widget.friend.userCode,
                        style: MoaiText.body(
                          context,
                          color: descColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? scheme.onPrimary.withValues(alpha: 0.22)
                              : widget.friend.isOnline
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.friend.isOnline
                                    ? Colors.greenAccent.shade400
                                    : scheme.outlineVariant,
                              ),
                            ),
                            const SizedBox(width: 5),
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
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _IconButtonAction(
              focusNode: widget.focusNode,
              tooltip: 'friends_delete_button'.tr(),
              icon: Icons.delete_outline_rounded,
              onPressed: widget.onDelete,
              parentFocused: isFocused,
              onKeyUp: widget.onKeyUp,
              onKeyDown: widget.onKeyDown,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback? onFocusRight;
  final VoidCallback? onFocusDown;

  const _BackButton({
    required this.focusNode,
    required this.onPressed,
    this.onFocusRight,
    this.onFocusDown,
  });

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final fg = _isFocused ? scheme.onPrimary : scheme.onSurface;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight && widget.onFocusRight != null) {
          widget.onFocusRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onFocusDown != null) {
          widget.onFocusDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(
                Icons.arrow_back_rounded,
                color: fg,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButtonAction extends StatefulWidget {
  final FocusNode focusNode;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool parentFocused;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const _IconButtonAction({
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.parentFocused,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<_IconButtonAction> createState() => _IconButtonActionState();
}

class _IconButtonActionState extends State<_IconButtonAction> {
  late bool _isFocused;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;

    if (_isFocused) {
      if (widget.parentFocused) {
        bg = scheme.onPrimary;
        fg = scheme.primary;
      } else {
        bg = scheme.primary;
        fg = scheme.onPrimary;
      }
    } else if (widget.parentFocused) {
      bg = scheme.onPrimary.withValues(alpha: 0.18);
      fg = scheme.onPrimary;
    } else {
      bg = scheme.secondaryContainer.withValues(alpha: 0.7);
      fg = scheme.onSecondaryContainer;
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: () {
            if (_isFocused) {
              widget.onPressed();
            } else {
              widget.focusNode.requestFocus();
            }
          },
          child: AnimatedScale(
            scale: _isFocused ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
