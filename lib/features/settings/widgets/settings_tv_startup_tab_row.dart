import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/theme/moai_icons.dart';

class SettingsTvStartupTabRow extends StatelessWidget {
  final FocusNode focusNode;
  final TvTab selectedTab;
  final ValueChanged<TvTab> onChanged;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsTvStartupTabRow({
    super.key,
    required this.focusNode,
    required this.selectedTab,
    required this.onChanged,
    required this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  static String _label(TvTab tab) => switch (tab) {
        TvTab.explore => LocaleKeys.home_tab_explore,
        TvTab.search => LocaleKeys.home_tab_search,
        TvTab.groups => LocaleKeys.home_tab_groups,
      }.tr();

  @override
  Widget build(BuildContext context) {
    return SettingsOptionRow<TvTab>(
      focusNode: focusNode,
      label: LocaleKeys.settings_tv_startup_tab.tr(),
      description: LocaleKeys.settings_tv_startup_tab_desc.tr(),
      icon: MoaiIcons.settingsTvStartupTab,
      options: TvTab.values,
      selected: selectedTab,
      onChanged: onChanged,
      labelBuilder: _label,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
