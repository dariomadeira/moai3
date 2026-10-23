import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_option_selector.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

class SettingsAgendaSnackDurationRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedSeconds;
  final ValueChanged<int> onChanged;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAgendaSnackDurationRow({
    super.key,
    required this.focusNode,
    required this.selectedSeconds,
    required this.onChanged,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    2: LocaleKeys.settings_agenda_snack_short,
    4: LocaleKeys.settings_agenda_snack_medium,
    8: LocaleKeys.settings_agenda_snack_long,
  };

  int get _selectedIndex {
    final i = CalendarProvider.snackDurationOptions.indexOf(selectedSeconds);
    return i < 0
        ? CalendarProvider.snackDurationOptions
            .indexOf(CalendarProvider.defaultSnackDurationSeconds)
        : i;
  }

  void _selectIndex(int index) {
    const options = CalendarProvider.snackDurationOptions;
    if (index < 0 || index >= options.length) return;
    final next = options[index];
    if (next != selectedSeconds) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = CalendarProvider.snackDurationOptions;
    final selectedIndex = _selectedIndex;

    return TvTile(
      focusNode: focusNode,
      label: LocaleKeys.settings_agenda_snack_duration.tr(),
      description: LocaleKeys.settings_agenda_snack_duration_desc.tr(),
      icon: MoaiIcons.timerOutlined,
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
          selectedValue: selectedSeconds,
          onSelect: onChanged,
          labelBuilder: (option) => _labelKeys[option]!.tr(),
          isFocused: isFocused,
        );
      },
    );
  }
}
