import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/dialogs/tv_pin_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';

enum _SettingsTvItemType {
  debugLog,
  channelLabels,
  adultContent,
  changePin,
  sources,
}

class SettingsTvPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsTvPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsTvPanel> createState() => SettingsTvPanelState();
}

class SettingsTvPanelState extends State<SettingsTvPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey = GlobalKey<TvWindowedListState<_SettingsTvItemType>>();
  int _selectedIndex = 0;

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
              title: 'settings_tv_title'.tr(),
              subtitle: 'settings_tv_subtitle'.tr(),
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
      case _SettingsTvItemType.debugLog:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: AppIcons.debugLog(),
          iconAccentColor: const Color(0xFFFFB74D),
          label: 'settings_tv_log'.tr(),
          description: 'settings_tv_log_desc'.tr(),
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
          icon: AppIcons.channelLabels(),
          iconAccentColor: const Color(0xFF4FC3F7),
          label: 'settings_tv_channel_labels'.tr(),
          description: 'settings_tv_channel_labels_desc'.tr(),
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
          icon: AppIcons.adultContent(),
          iconAccentColor: const Color(0xFFFF5252),
          label: 'settings_tv_adult_content'.tr(),
          description: 'settings_tv_adult_content_desc'.tr(),
          value: tvSettings.isAdultUnlocked,
          onChanged: (enable) async {
            if (enable) {
              await TvPinDialog.unlockAdultSession(context, tvSettings);
            } else {
              tvSettings.lockAdult();
              if (context.mounted) {
                MoaiSnackBar.show(
                  context,
                  message: 'parental_adult_locked'.tr(),
                  icon: Symbols.lock,
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
          icon: Icons.pin_outlined,
          iconAccentColor: const Color(0xFFBA68C8),
          label: 'settings_tv_change_pin'.tr(),
          description: 'settings_tv_change_pin_desc'.tr(),
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
          icon: AppIcons.sources(),
          iconAccentColor: const Color(0xFF81C784),
          label: 'settings_general_sources'.tr(),
          description: 'settings_general_sources_desc'.tr(),
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

