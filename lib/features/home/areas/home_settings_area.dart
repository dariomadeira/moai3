import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row.dart';
import 'package:moai3/features/settings/widgets/settings_about_panel.dart';
import 'package:moai3/features/settings/widgets/settings_general_panel.dart';
import 'package:moai3/features/settings/widgets/settings_tv_panel.dart';
import 'package:moai3/layout/settings_panel_layout.dart';
import 'package:moai3/theme/moai_text.dart';

/// Acordeón de Ajustes (UI). Los [FocusNode] viven en el padre (como moaiSmart).
class HomeSettingsArea extends StatelessWidget {
  final int activePanelIndex;
  final FocusNode tvPanelFocus;
  final FocusNode generalPanelFocus;
  final FocusNode aboutPanelFocus;
  final ValueChanged<int> onPanelIndexChanged;
  final VoidCallback onExitLeft;

  const HomeSettingsArea({
    super.key,
    required this.activePanelIndex,
    required this.tvPanelFocus,
    required this.generalPanelFocus,
    required this.aboutPanelFocus,
    required this.onPanelIndexChanged,
    required this.onExitLeft,
  });

  static const icons = [
    Icons.settings_remote_outlined,
    Icons.tune,
    Icons.info_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final panelColors = [
      scheme.surface,
      scheme.surface,
      scheme.surface,
    ];
    final titles = [
      'settings_tv_title'.tr(),
      'settings_general_title'.tr(),
      'settings_about_title'.tr(),
    ];

    return TvAccordionRow(
      panelCount: SettingsPanelLayout.panelCount,
      activeIndex: activePanelIndex,
      colors: panelColors,
      titles: titles,
      icons: icons,
      onPanelTap: onPanelIndexChanged,
      buildExpandedContent: (index, title) {
        if (SettingsPanelLayout.isConfigTvPanel(index)) {
          return SettingsTvPanel(
            focusNode: tvPanelFocus,
            onKeyLeft: onExitLeft,
            onKeyRight: () => onPanelIndexChanged(
              SettingsPanelLayout.configGeneralPanelIndex,
            ),
          );
        }

        if (SettingsPanelLayout.isConfigGeneralPanel(index)) {
          return SettingsGeneralPanel(
            focusNode: generalPanelFocus,
            onKeyLeft: () => onPanelIndexChanged(
              SettingsPanelLayout.configTvPanelIndex,
            ),
            onKeyRight: () => onPanelIndexChanged(
              SettingsPanelLayout.aboutPanelIndex,
            ),
          );
        }

        return SettingsAboutPanel(
          focusNode: aboutPanelFocus,
          onKeyLeft: () => onPanelIndexChanged(
            SettingsPanelLayout.configGeneralPanelIndex,
          ),
        );
      },
    );
  }
}

