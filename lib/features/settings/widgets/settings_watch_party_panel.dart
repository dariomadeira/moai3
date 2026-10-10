import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/context_extensions.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_nickname_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_voice_test_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';

enum _SettingsWatchPartyItemType {
  watchPartySwitch,
  watchPartyNickname,
  watchPartyCodeCard,
  watchPartyManageFriends,
  micTest,
}

/// Panel independiente de Ajustes para "Miremos Juntos" (Watch Party).
class SettingsWatchPartyPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsWatchPartyPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsWatchPartyPanel> createState() => SettingsWatchPartyPanelState();
}

class SettingsWatchPartyPanelState extends State<SettingsWatchPartyPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey =
      GlobalKey<TvWindowedListState<_SettingsWatchPartyItemType>>();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final wp = context.readOptional<WatchPartyProvider>();
        if (wp != null && wp.enabled) {
          wp.ensureUserCode();
          wp.fetchNickname();
        }
      }
    });
  }

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final watchParty = context.watchOptional<WatchPartyProvider>();
    final isEnabled = watchParty?.enabled ?? false;

    final items = <_SettingsWatchPartyItemType>[
      _SettingsWatchPartyItemType.watchPartySwitch,
      if (isEnabled) ...[
        _SettingsWatchPartyItemType.watchPartyNickname,
        _SettingsWatchPartyItemType.watchPartyCodeCard,
        _SettingsWatchPartyItemType.watchPartyManageFriends,
        _SettingsWatchPartyItemType.micTest,
      ],
    ];

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(
          left: 4,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: 'settings_watch_party_title'.tr(),
              subtitle: 'settings_watch_party_subtitle'.tr(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetHeight = (_windowSize * _itemExtent)
                      .clamp(0.0, constraints.maxHeight);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: targetHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TvWindowedList<_SettingsWatchPartyItemType>(
                          key: _listKey,
                          items: items,
                          windowSize: _windowSize,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                          },
                          itemBuilder: (
                            context,
                            item,
                            focusNode,
                            local,
                            global,
                            onKeyUp,
                            onKeyDown,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _buildItem(
                                context: context,
                                item: item,
                                watchParty: watchParty,
                                focusNode: focusNode,
                                onKeyUp: onKeyUp,
                                onKeyDown: onKeyDown,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required _SettingsWatchPartyItemType item,
    WatchPartyProvider? watchParty,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _SettingsWatchPartyItemType.watchPartySwitch:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: AppIcons.watchParty,
          label: 'settings_tv_watch_party'.tr(),
          description: 'settings_tv_watch_party_desc'.tr(),
          value: watchParty?.enabled ?? false,
          onChanged: (v) => _handleToggleWatchParty(context, watchParty, v),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsWatchPartyItemType.watchPartyNickname:
        final currentNickname = watchParty?.nickname;
        final hasNick =
            currentNickname != null && currentNickname.trim().isNotEmpty;
        return TvTile(
          focusNode: focusNode,
          icon: AppIcons.person,
          label: 'settings_watch_party_nickname'.tr(),
          description: 'settings_watch_party_nickname_desc'.tr(),
          onPressed: () => _openEditNicknameDialog(context, watchParty),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused ? scheme.onPrimary : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                hasNick
                    ? currentNickname
                    : 'settings_watch_party_nickname_none'.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isFocused ? scheme.primary : scheme.onPrimaryContainer,
                ),
              ),
            );
          },
        );
      case _SettingsWatchPartyItemType.watchPartyCodeCard:
        return TvTile(
          focusNode: focusNode,
          icon: AppIcons.badge,
          label: 'settings_tv_watch_party_code'.tr(),
          description: 'settings_tv_watch_party_code_desc'.tr(),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isFocused ? scheme.onPrimary : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                watchParty?.userCode ?? 'MOAI-????',
                style: MoaiText.display(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: isFocused ? scheme.primary : scheme.onPrimaryContainer,
                ),
              ),
            );
          },
        );
      case _SettingsWatchPartyItemType.watchPartyManageFriends:
        final friendsCount = watchParty?.friends.length ?? 0;
        final onlineCount = watchParty?.onlineFriendsCount ?? 0;
        final String statusDesc;
        if (friendsCount == 0) {
          statusDesc = 'settings_tv_friends_count_zero'.tr();
        } else if (friendsCount == 1) {
          statusDesc = 'settings_tv_friends_count_single'.tr(
            namedArgs: {'count': '1', 'online': '$onlineCount'},
          );
        } else {
          statusDesc = 'settings_tv_friends_count_plural'.tr(
            namedArgs: {'count': '$friendsCount', 'online': '$onlineCount'},
          );
        }
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: AppIcons.friends,
          label: 'settings_tv_manage_friends'.tr(),
          description: statusDesc,
          onPressed: () {
            TvFriendsDialog.show(context);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsWatchPartyItemType.micTest:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: AppIcons.voiceTest,
          label: 'settings_tv_mic_test'.tr(),
          description: 'settings_tv_mic_test_desc'.tr(),
          onPressed: () {
            TvVoiceTestDialog.show(context);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }

  Future<void> _handleToggleWatchParty(
    BuildContext context,
    WatchPartyProvider? watchParty,
    bool value,
  ) async {
    if (watchParty == null) return;
    if (!value) {
      setState(() {
        _selectedIndex = 0;
      });
      await watchParty.setEnabled(false);
      return;
    }

    var currentNick = watchParty.nickname;
    if (currentNick == null || currentNick.trim().isEmpty) {
      currentNick = await watchParty.fetchNickname();
    }

    if (currentNick == null || currentNick.trim().isEmpty) {
      if (!context.mounted) return;
      final newNick = await TvNicknameDialog.show(
        context,
        isMandatory: true,
      );

      if (newNick != null && newNick.trim().isNotEmpty) {
        try {
          await watchParty.updateNickname(newNick.trim());
        } catch (_) {}
        await watchParty.setEnabled(true);
      }
    } else {
      await watchParty.setEnabled(true);
    }
  }

  Future<void> _openEditNicknameDialog(
    BuildContext context,
    WatchPartyProvider? watchParty,
  ) async {
    if (watchParty == null) return;
    final currentNick = watchParty.nickname ?? '';
    final newNick = await TvNicknameDialog.show(
      context,
      initialNickname: currentNick,
      isMandatory: false,
    );

    if (newNick != null &&
        newNick.trim().isNotEmpty &&
        newNick.trim() != currentNick.trim()) {
      try {
        await watchParty.updateNickname(newNick.trim());
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: 'nickname_dialog_saved_success'.tr(),
            icon: AppIcons.check,
          );
        }
      } catch (e) {
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: 'nickname_dialog_saved_error'.tr(),
            icon: AppIcons.error,
          );
        }
      }
    }
  }
}
