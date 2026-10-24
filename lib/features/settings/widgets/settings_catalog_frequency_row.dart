import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
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

  @override
  Widget build(BuildContext context) {
    return SettingsOptionRow<CatalogUpdateFrequency>(
      focusNode: focusNode,
      label: label ?? LocaleKeys.settings_general_catalog_frequency.tr(),
      description: LocaleKeys.settings_general_catalog_frequency_desc.tr(),
      icon: MoaiIcons.refresh,
      options: CatalogUpdateFrequency.options,
      selected: selected,
      onChanged: onChanged,
      labelBuilder: (option) => _labelKeys[option]!.tr(),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
