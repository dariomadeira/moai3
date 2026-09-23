import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_pin_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:provider/provider.dart';

enum _SettingsTvItemType {
  debugLog,
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
  static const double _itemExtent = 74.0;

  final _listKey = GlobalKey<TvWindowedListState<_SettingsTvItemType>>();
  int _selectedIndex = 0;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tvSettings = context.watch<TvSettingsProvider>();
    final hasPin = tvSettings.hasParentalPin;

    final items = <_SettingsTvItemType>[
      _SettingsTvItemType.debugLog,
      _SettingsTvItemType.adultContent,
      if (hasPin) _SettingsTvItemType.changePin,
      _SettingsTvItemType.sources,
    ];

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    final listAlign = items.length < _windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

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
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'settings_tv_title'.tr(),
                    style: MoaiText.display(
                      context,
                      color: scheme.onSurface,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings_tv_subtitle'.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: listAlign,
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
          icon: Icons.terminal_outlined,
          label: 'settings_tv_log'.tr(),
          description: 'settings_tv_log_desc'.tr(),
          value: tvSettings.showTvLog,
          onChanged: (v) => tvSettings.setShowTvLog(v),
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsTvItemType.adultContent:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: tvSettings.isAdultUnlocked ? Symbols.lock_open : Symbols.lock,
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
          icon: Symbols.extension,
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
