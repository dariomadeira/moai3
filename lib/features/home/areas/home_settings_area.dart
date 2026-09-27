import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_about_panel.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_panel.dart';
import 'package:moai3/features/settings/widgets/settings_general_panel.dart';
import 'package:moai3/features/settings/widgets/settings_tv_panel.dart';
import 'package:moai3/layout/settings_panel_layout.dart';
import 'package:moai3/theme/moai_text.dart';

/// Acordeón de Ajustes (UI). Los [FocusNode] viven en el padre (como moaiSmart).
class HomeSettingsArea extends StatelessWidget {
  final int activePanelIndex;
  final FocusNode tvPanelFocus;
  final FocusNode generalPanelFocus;
  final FocusNode agendaPanelFocus;
  final FocusNode aboutPanelFocus;
  final ValueChanged<int> onPanelIndexChanged;
  final VoidCallback onExitLeft;

  const HomeSettingsArea({
    super.key,
    required this.activePanelIndex,
    required this.tvPanelFocus,
    required this.generalPanelFocus,
    required this.agendaPanelFocus,
    required this.aboutPanelFocus,
    required this.onPanelIndexChanged,
    required this.onExitLeft,
  });

  static const icons = [
    Icons.settings_remote_outlined,
    Icons.calendar_month_outlined,
    Icons.tune_outlined,
    Icons.info_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final panelColors = [
      scheme.surface.withValues(alpha: 0.8),
      scheme.surface.withValues(alpha: 0.8),
      scheme.surface.withValues(alpha: 0.8),
      scheme.surface.withValues(alpha: 0.8),
    ];
    final titles = [
      'settings_tv_title'.tr(),
      'settings_agenda_title'.tr(),
      'settings_general_title'.tr(),
      'settings_about_title'.tr(),
    ];

    return TvAccordionRowPreview(
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
              SettingsPanelLayout.configAgendaPanelIndex,
            ),
          );
        }

        if (SettingsPanelLayout.isConfigAgendaPanel(index)) {
          return SettingsAgendaPanel(
            focusNode: agendaPanelFocus,
            onKeyLeft: () => onPanelIndexChanged(
              SettingsPanelLayout.configTvPanelIndex,
            ),
            onKeyRight: () => onPanelIndexChanged(
              SettingsPanelLayout.configGeneralPanelIndex,
            ),
          );
        }

        if (SettingsPanelLayout.isConfigGeneralPanel(index)) {
          return SettingsGeneralPanel(
            focusNode: generalPanelFocus,
            onKeyLeft: () => onPanelIndexChanged(
              SettingsPanelLayout.configAgendaPanelIndex,
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

