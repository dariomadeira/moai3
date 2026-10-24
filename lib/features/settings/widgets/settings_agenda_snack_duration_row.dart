import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

class SettingsAgendaSnackDurationRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedSeconds;
  final ValueChanged<int> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAgendaSnackDurationRow({
    super.key,
    required this.focusNode,
    required this.selectedSeconds,
    required this.onChanged,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    2: LocaleKeys.settings_agenda_snack_short,
    4: LocaleKeys.settings_agenda_snack_medium,
    8: LocaleKeys.settings_agenda_snack_long,
  };

  @override
  Widget build(BuildContext context) {
    const options = CalendarProvider.snackDurationOptions;
    return SettingsOptionRow<int>(
      focusNode: focusNode,
      label: LocaleKeys.settings_agenda_snack_duration.tr(),
      description: LocaleKeys.settings_agenda_snack_duration_desc.tr(),
      icon: MoaiIcons.timer,
      options: options,
      selected: options.contains(selectedSeconds)
          ? selectedSeconds
          : CalendarProvider.defaultSnackDurationSeconds,
      onChanged: onChanged,
      labelBuilder: (option) => _labelKeys[option]!.tr(),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
