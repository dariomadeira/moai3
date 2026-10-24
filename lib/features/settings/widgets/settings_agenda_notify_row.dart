import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

class SettingsAgendaNotifyRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAgendaNotifyRow({
    super.key,
    required this.focusNode,
    required this.selectedMinutes,
    required this.onChanged,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    0: LocaleKeys.settings_agenda_notify_now,
    10: LocaleKeys.settings_agenda_notify_10,
    15: LocaleKeys.settings_agenda_notify_15,
    30: LocaleKeys.settings_agenda_notify_30,
  };

  @override
  Widget build(BuildContext context) {
    const options = CalendarProvider.notifyLeadOptions;
    return SettingsOptionRow<int>(
      focusNode: focusNode,
      label: LocaleKeys.settings_agenda_notify.tr(),
      description: LocaleKeys.settings_agenda_notify_desc.tr(),
      icon: MoaiIcons.notifications,
      options: options,
      selected: options.contains(selectedMinutes)
          ? selectedMinutes
          : options.first,
      onChanged: onChanged,
      labelBuilder: (option) => _labelKeys[option]!.tr(),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
