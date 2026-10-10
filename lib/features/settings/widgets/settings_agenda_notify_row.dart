import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_option_selector.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/app_icons.dart';

class SettingsAgendaNotifyRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final Color? iconAccentColor;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAgendaNotifyRow({
    super.key,
    required this.focusNode,
    required this.selectedMinutes,
    required this.onChanged,
    this.iconAccentColor,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    0: 'settings_agenda_notify_now',
    10: 'settings_agenda_notify_10',
    15: 'settings_agenda_notify_15',
    30: 'settings_agenda_notify_30',
  };

  int get _selectedIndex {
    final i = CalendarProvider.notifyLeadOptions.indexOf(selectedMinutes);
    return i < 0 ? 0 : i;
  }

  void _selectIndex(int index) {
    final options = CalendarProvider.notifyLeadOptions;
    if (index < 0 || index >= options.length) return;
    final next = options[index];
    if (next != selectedMinutes) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = CalendarProvider.notifyLeadOptions;
    final selectedIndex = _selectedIndex;

    return TvTile(
      focusNode: focusNode,
      label: 'settings_agenda_notify'.tr(),
      description: 'settings_agenda_notify_desc'.tr(),
      icon: AppIcons.notifyLead(),
      iconAccentColor: iconAccentColor,
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
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (selectedIndex < options.length - 1) {
            _selectIndex(selectedIndex + 1);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      trailingBuilder: (context, isFocused) {
        return TvOptionSelector<int>(
          options: options,
          selectedValue: selectedMinutes,
          onSelect: onChanged,
          labelBuilder: (option) => _labelKeys[option]!.tr(),
          isFocused: isFocused,
          accentColor: iconAccentColor,
        );
      },
    );
  }
}
