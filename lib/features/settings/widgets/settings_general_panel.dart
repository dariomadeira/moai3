import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/bootstrap/screens/overlap_config_screen.dart';
import 'package:moai3/features/settings/widgets/settings_accent_color_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:provider/provider.dart';

enum _SettingsGeneralItemType {
  overscan,
  darkMode,
  accentColor,
  autoAccent,
}

class SettingsGeneralPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsGeneralPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsGeneralPanel> createState() => SettingsGeneralPanelState();
}

class SettingsGeneralPanelState extends State<SettingsGeneralPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 74.0;

  final _listKey = GlobalKey<TvWindowedListState<_SettingsGeneralItemType>>();
  int _selectedIndex = 0;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = context.watch<ThemeProvider>();
    final isAutoAccent = theme.autoAccent;

    final items = <_SettingsGeneralItemType>[
      _SettingsGeneralItemType.overscan,
      _SettingsGeneralItemType.darkMode,
      if (!isAutoAccent) _SettingsGeneralItemType.accentColor,
      _SettingsGeneralItemType.autoAccent,
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
                    'settings_general_title'.tr(),
                    style: MoaiText.display(
                      context,
                      color: scheme.onSurface,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'settings_general_subtitle'.tr(),
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
                child: TvWindowedList<_SettingsGeneralItemType>(
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
                        theme: theme,
                        isAutoAccent: isAutoAccent,
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
    required _SettingsGeneralItemType item,
    required ThemeProvider theme,
    required bool isAutoAccent,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _SettingsGeneralItemType.overscan:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: Icons.aspect_ratio_outlined,
          label: 'settings_general_overscan'.tr(),
          description: 'settings_general_overscan_desc'.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const OverlapConfigScreen(isFirstRun: false),
              ),
            );
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.darkMode:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: Icons.dark_mode_outlined,
          label: 'settings_general_dark_mode'.tr(),
          description: 'settings_general_dark_mode_desc'.tr(),
          value: theme.themeMode == ThemeMode.dark,
          onChanged: (isDark) {
            theme.setDarkMode(isDark);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.accentColor:
        return SettingsAccentColorRow(
          focusNode: focusNode,
          icon: Icons.palette_outlined,
          selectedIndex: theme.accentColorIndex,
          onChanged: (index) => theme.setAccentColorIndex(index),
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.autoAccent:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: Icons.auto_awesome_outlined,
          label: 'settings_general_auto_accent'.tr(),
          description: 'settings_general_auto_accent_desc'.tr(),
          value: isAutoAccent,
          onChanged: (auto) {
            theme.setAutoAccent(auto);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}
