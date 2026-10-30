import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:provider/provider.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_nickname_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_voice_test_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_value_chip.dart';
import 'package:moai3/theme/moai_icons.dart';

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
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsWatchPartyPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<SettingsWatchPartyPanel> createState() => SettingsWatchPartyPanelState();
}

class SettingsWatchPartyPanelState extends State<SettingsWatchPartyPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey =
      GlobalKey<TvWindowedListState<_SettingsWatchPartyItemType>>();
  late int _selectedIndex = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final wp = context.read<WatchPartyProvider?>();
        if (wp != null && wp.enabled) {
          wp.ensureUserCode();
          wp.fetchNickname(forceRemote: true);
        }
      }
    });
  }

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final watchParty = context.watch<WatchPartyProvider?>();
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
              title: LocaleKeys.settings_watch_party_title.tr(),
              subtitle: LocaleKeys.settings_watch_party_subtitle.tr(),
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
                          // La entrada de foco la decide el área (rail →, cambio de panel).
                          focusOnMount: false,
                          items: items,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                            widget.onSelectedIndexChanged?.call(idx);
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
          icon: MoaiIcons.voice,
          label: LocaleKeys.settings_tv_watch_party.tr(),
          description: LocaleKeys.settings_tv_watch_party_desc.tr(),
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
          icon: MoaiIcons.profile,
          label: LocaleKeys.settings_watch_party_nickname.tr(),
          description: LocaleKeys.settings_watch_party_nickname_desc.tr(),
          onPressed: () => _openEditNicknameDialog(context, watchParty),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            return TvValueChip(
              text: hasNick
                  ? currentNickname
                  : LocaleKeys.settings_watch_party_nickname_none.tr(),
              isFocused: isFocused,
            );
          },
        );
      case _SettingsWatchPartyItemType.watchPartyCodeCard:
        return TvTile(
          focusNode: focusNode,
          icon: MoaiIcons.nickname,
          label: LocaleKeys.settings_tv_watch_party_code.tr(),
          description: LocaleKeys.settings_tv_watch_party_code_desc.tr(),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            return TvValueChip(
              text: watchParty?.userCode ?? 'MOAI-????',
              isFocused: isFocused,
            );
          },
        );
      case _SettingsWatchPartyItemType.watchPartyManageFriends:
        final friendsCount = watchParty?.friends.length ?? 0;
        final onlineCount = watchParty?.onlineFriendsCount ?? 0;
        final String statusDesc;
        if (friendsCount == 0) {
          statusDesc = LocaleKeys.settings_tv_friends_count_zero.tr();
        } else if (friendsCount == 1) {
          statusDesc = LocaleKeys.settings_tv_friends_count_single.tr(
            namedArgs: {'count': '1', 'online': '$onlineCount'},
          );
        } else {
          statusDesc = LocaleKeys.settings_tv_friends_count_plural.tr(
            namedArgs: {'count': '$friendsCount', 'online': '$onlineCount'},
          );
        }
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.watchPartyFriends,
          label: LocaleKeys.settings_tv_manage_friends.tr(),
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
          icon: MoaiIcons.micSettings,
          label: LocaleKeys.settings_tv_mic_test.tr(),
          description: LocaleKeys.settings_tv_mic_test_desc.tr(),
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
        } catch (e) {
          debugPrint('[SettingsWatchPartyPanel] $e');
        }
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
    );

    if (newNick != null &&
        newNick.trim().isNotEmpty &&
        newNick.trim() != currentNick.trim()) {
      try {
        await watchParty.updateNickname(newNick.trim());
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: LocaleKeys.nickname_dialog_saved_success.tr(),
            icon: MoaiIcons.checkCircle,
          );
        }
      } catch (e) {
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: LocaleKeys.nickname_dialog_saved_error.tr(),
            icon: MoaiIcons.error,
          );
        }
      }
    }
  }
}
