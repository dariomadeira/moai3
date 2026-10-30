import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_tv_startup_tab_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/dialogs/tv_pin_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

enum _SettingsTvItemType {
  debugLog,
  channelLabels,
  adultContent,
  changePin,
  startupTab,
  sources,
}

class SettingsTvPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsTvPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<SettingsTvPanel> createState() => SettingsTvPanelState();
}

class SettingsTvPanelState extends State<SettingsTvPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey = GlobalKey<TvWindowedListState<_SettingsTvItemType>>();
  late int _selectedIndex = widget.initialIndex;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final tvSettings = context.watch<TvSettingsProvider>();
    final hasPin = tvSettings.hasParentalPin;

    final items = <_SettingsTvItemType>[
      _SettingsTvItemType.debugLog,
      _SettingsTvItemType.channelLabels,
      _SettingsTvItemType.adultContent,
      if (hasPin) _SettingsTvItemType.changePin,
      _SettingsTvItemType.startupTab,
      _SettingsTvItemType.sources,
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
              title: LocaleKeys.settings_tv_title.tr(),
              subtitle: LocaleKeys.settings_tv_subtitle.tr(),
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
                        child: TvWindowedList<_SettingsTvItemType>(
                          key: _listKey,
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
                                tvSettings: tvSettings,
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
    required _SettingsTvItemType item,
    required TvSettingsProvider tvSettings,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _SettingsTvItemType.startupTab:
        return SettingsTvStartupTabRow(
          focusNode: focusNode,
          selectedTab: tvSettings.startupTvTab,
          onChanged: (tab) => tvSettings.setStartupTvTab(tab),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.debugLog:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.debugPanel,
          label: LocaleKeys.settings_tv_log.tr(),
          description: LocaleKeys.settings_tv_log_desc.tr(),
          value: tvSettings.showTvLog,
          onChanged: (v) => tvSettings.setShowTvLog(v),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.channelLabels:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.channelLabels,
          label: LocaleKeys.settings_tv_channel_labels.tr(),
          description: LocaleKeys.settings_tv_channel_labels_desc.tr(),
          value: tvSettings.showChannelLabels,
          onChanged: (v) => tvSettings.setShowChannelLabels(v),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.adultContent:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: tvSettings.isAdultUnlocked ? MoaiIcons.lockOpen : MoaiIcons.lock,
          label: LocaleKeys.settings_tv_adult_content.tr(),
          description: LocaleKeys.settings_tv_adult_content_desc.tr(),
          value: tvSettings.isAdultUnlocked,
          onChanged: (enable) async {
            if (enable) {
              await TvPinDialog.unlockAdultSession(context, tvSettings);
            } else {
              tvSettings.lockAdult();
              if (context.mounted) {
                MoaiSnackBar.show(
                  context,
                  message: LocaleKeys.parental_adult_locked.tr(),
                  icon: MoaiIcons.lock,
                );
              }
            }
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.changePin:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.pin,
          label: LocaleKeys.settings_tv_change_pin.tr(),
          description: LocaleKeys.settings_tv_change_pin_desc.tr(),
          onPressed: () async {
            await TvPinDialog.changePin(context, tvSettings);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.sources:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.extension,
          label: LocaleKeys.settings_general_sources.tr(),
          description: LocaleKeys.settings_general_sources_desc.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const SourcesScreen(),
              ),
            );
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}

