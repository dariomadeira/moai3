import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_option_selector.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

class SettingsCatalogFrequencyRow extends StatelessWidget {
  final FocusNode focusNode;

  /// Por defecto, el título de la frecuencia.
  final String? label;
  final CatalogUpdateFrequency selected;
  final ValueChanged<CatalogUpdateFrequency> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsCatalogFrequencyRow({
    super.key,
    required this.focusNode,
    this.label,
    required this.selected,
    required this.onChanged,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    CatalogUpdateFrequency.always:
        LocaleKeys.settings_general_catalog_freq_always,
    CatalogUpdateFrequency.weekly:
        LocaleKeys.settings_general_catalog_freq_weekly,
    CatalogUpdateFrequency.monthly:
        LocaleKeys.settings_general_catalog_freq_monthly,
  };

  int get _selectedIndex {
    final i = CatalogUpdateFrequency.options.indexOf(selected);
    return i < 0
        ? CatalogUpdateFrequency.options.indexOf(
            CatalogUpdateFrequency.defaultValue,
          )
        : i;
  }

  void _selectIndex(int index) {
    const options = CatalogUpdateFrequency.options;
    if (index < 0 || index >= options.length) return;
    final next = options[index];
    if (next != selected) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    const options = CatalogUpdateFrequency.options;
    final selectedIndex = _selectedIndex;

    return TvTile(
      focusNode: focusNode,
      label: label ?? LocaleKeys.settings_general_catalog_frequency.tr(),
      description: LocaleKeys.settings_general_catalog_frequency_desc.tr(),
      icon: MoaiIcons.refresh,
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
          } else {
            onKeyLeft?.call();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (selectedIndex < options.length - 1) {
            _selectIndex(selectedIndex + 1);
          } else {
            onKeyRight?.call();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      trailingBuilder: (context, isFocused) {
        return TvOptionSelector<CatalogUpdateFrequency>(
          options: options,
          selectedValue: selected,
          onSelect: onChanged,
          labelBuilder: (option) => _labelKeys[option]!.tr(),
          isFocused: isFocused,
        );
      },
    );
  }
}
