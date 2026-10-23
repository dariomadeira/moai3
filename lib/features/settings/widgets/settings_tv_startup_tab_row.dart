import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_option_selector.dart';
import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';

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

  void _selectIndex(int index) {
    const options = TvTab.values;
    if (index < 0 || index >= options.length) return;
    final next = options[index];
    if (next != selectedTab) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = TvTab.values;
    final selectedIndex = selectedTab.index;

    return TvTile(
      focusNode: focusNode,
      label: LocaleKeys.settings_tv_startup_tab.tr(),
      description: LocaleKeys.settings_tv_startup_tab_desc.tr(),
      icon: MoaiIcons.settingsTvStartupTab,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.arrowUp && onKeyUp != null) {
          onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && onKeyDown != null) {
          onKeyDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (selectedIndex > 0) {
            _selectIndex(selectedIndex - 1);
            return KeyEventResult.handled;
          }
          onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (selectedIndex < options.length - 1) {
            _selectIndex(selectedIndex + 1);
            return KeyEventResult.handled;
          }
          if (onKeyRight != null) {
            onKeyRight!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      trailingBuilder: (context, isFocused) {
        return TvOptionSelector<TvTab>(
          options: options,
          selectedValue: selectedTab,
          onSelect: onChanged,
          labelBuilder: _label,
          isFocused: isFocused,
        );
      },
    );
  }
}
