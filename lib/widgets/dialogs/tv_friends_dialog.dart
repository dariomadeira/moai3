import 'dart:math';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_add_friend_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

part 'tv_friends/tv_friends_sections.dart';
part 'tv_friends/friend_tile.dart';
part 'tv_friends/request_tile.dart';

String _formatFriendsCount(int total, int online) {
  if (total == 0) return '';
  if (total == 1) {
    return LocaleKeys.settings_tv_friends_count_single.tr(
      namedArgs: {'count': '1', 'online': '$online'},
    );
  }
  return LocaleKeys.settings_tv_friends_count_plural.tr(
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
      barrierLabel: 'TvFriendsDialog',
      builder: (dialogContext) => const TvFriendsDialog(),
    );
  }

  @override
  State<TvFriendsDialog> createState() => _TvFriendsDialogState();
}

class _TvFriendsDialogState extends State<TvFriendsDialog> {
  static const int _windowSize = 3;
  static const double _itemExtent = 58.0;

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
      barrierLabel: 'DeleteFriendConfirm',
      builder: (dialogContext) {
        final cancelFocus = FocusNode(debugLabel: 'delete_cancel');
        final deleteFocus = FocusNode(debugLabel: 'delete_confirm');
        return TvDialog(
          width: 460,
          icon: MoaiIcons.personRemove,
          title: LocaleKeys.friends_delete_confirm_title.tr(),
          subtitle: LocaleKeys.friends_delete_confirm_desc.tr(
            namedArgs: {'name': friend.nickname ?? friend.userCode},
          ),
          actions: [
            TvDialogButton(
              label: LocaleKeys.common_cancel.tr(),
              focusNode: cancelFocus,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              onKeyRight: deleteFocus.requestFocus,
            ),
            TvDialogButton(
              label: LocaleKeys.common_delete.tr(),
              variant: TvDialogButtonVariant.destructive,
              focusNode: deleteFocus,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              onKeyLeft: cancelFocus.requestFocus,
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
      icon: MoaiIcons.friends,
      title: LocaleKeys.friends_screen_title.tr(),
      subtitle: LocaleKeys.friends_screen_subtitle.tr(),
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
                    Icon(
                      MoaiIcons.error,
                      color: scheme.onErrorContainer,
                      size: MoaiIconSizes.sm,
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
                      icon: MoaiIcons.friends,
                      title: LocaleKeys.friends_section_friends.tr(),
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
                      icon: MoaiIcons.personAdd,
                      title: LocaleKeys.friends_section_requests.tr(),
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
          label: LocaleKeys.common_close.tr(),
          onPressed: () => Navigator.of(context).pop(),
          onKeyUp: () {
            if (friends.isNotEmpty) {
              _friendsListKey.currentState?.ensureVisible(
                friends.length - 1,
              );
            } else if (requests.isNotEmpty) {
              _requestsListKey.currentState?.ensureVisible(
                requests.length - 1,
              );
            } else {
              _addFocus.requestFocus();
            }
          },
        ),
      ],
    );
  }

}
