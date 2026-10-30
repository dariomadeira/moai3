import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_about_panel.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_panel.dart';
import 'package:moai3/features/settings/widgets/settings_general_panel.dart';
import 'package:moai3/features/settings/widgets/settings_movies_series_panel.dart';
import 'package:moai3/features/settings/widgets/settings_tv_panel.dart';
import 'package:moai3/features/settings/widgets/settings_watch_party_panel.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/settings_panel_layout.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Acordeón de Ajustes. Es dueño de sus [FocusNode]; el padre solo recuerda
/// el panel abierto para reabrirlo al volver a la sección.
class HomeSettingsArea extends StatefulWidget {
  final int initialPanelIndex;
  final ValueChanged<int>? onPanelIndexChanged;
  final VoidCallback onExitLeft;

  const HomeSettingsArea({
    super.key,
    this.initialPanelIndex = SettingsPanelLayout.configTvPanelIndex,
    this.onPanelIndexChanged,
    required this.onExitLeft,
  });

  static const icons = [
    MoaiIcons.tv,
    MoaiIcons.settingsMovies,
    MoaiIcons.calendarEvents,
    MoaiIcons.watchParty,
    MoaiIcons.settingsGeneral,
    MoaiIcons.info,
  ];

  @override
  State<HomeSettingsArea> createState() => _HomeSettingsAreaState();
}

class _HomeSettingsAreaState extends HomeAreaState<HomeSettingsArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  late int _panel = widget.initialPanelIndex;

  /// Guarda el ítem seleccionado de cada panel para conservarlo al ir y volver.
  final List<int> _panelItemIndices = List.filled(
    SettingsPanelLayout.panelCount,
    0,
  );

  /// Un nodo por panel, en el orden de [SettingsPanelLayout].
  final _panelFocus = [
    FocusNode(debugLabel: 'settings_tv'),
    FocusNode(debugLabel: 'settings_movies_series'),
    FocusNode(debugLabel: 'settings_agenda'),
    FocusNode(debugLabel: 'settings_watch_party'),
    FocusNode(debugLabel: 'settings_general'),
    FocusNode(debugLabel: 'settings_about'),
  ];

  @override
  void dispose() {
    for (final node in _panelFocus) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void requestEntryFocus() => _focus.node(_panelFocus[_panel], immediate: true);

  void _selectPanel(int index) {
    setState(() => _panel = index);
    widget.onPanelIndexChanged?.call(index);
    requestEntryFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final panelColors = List.filled(
      SettingsPanelLayout.panelCount,
      scheme.surface.withValues(alpha: 0.8),
    );
    final titles = [
      LocaleKeys.settings_tv_title.tr(),
      LocaleKeys.settings_movies_series_title.tr(),
      LocaleKeys.settings_agenda_title.tr(),
      LocaleKeys.settings_watch_party_title.tr(),
      LocaleKeys.settings_general_title.tr(),
      LocaleKeys.settings_about_title.tr(),
    ];

    // Ancho final fijo: interruptores y textos no se re-distribuyen mientras
    // el acordeón abre o cambia de panel.
    return TvAccordionRowPreview(
      panelCount: SettingsPanelLayout.panelCount,
      activeIndex: _panel,
      colors: panelColors,
      titles: titles,
      icons: HomeSettingsArea.icons,
      onPanelTap: _selectPanel,
      fixedContentWidth: true,
      buildExpandedContent: (index, title) {
        final focusNode = _panelFocus[index];
        final itemIndex = _panelItemIndices[index];
        void onItemChanged(int idx) => _panelItemIndices[index] = idx;

        final Widget panelWidget;
        if (SettingsPanelLayout.isConfigTvPanel(index)) {
          panelWidget = SettingsTvPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: widget.onExitLeft,
            onKeyRight: () =>
                _selectPanel(SettingsPanelLayout.configMoviesSeriesPanelIndex),
          );
        } else if (SettingsPanelLayout.isConfigMoviesSeriesPanel(index)) {
          panelWidget = SettingsMoviesSeriesPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: () =>
                _selectPanel(SettingsPanelLayout.configTvPanelIndex),
            onKeyRight: () =>
                _selectPanel(SettingsPanelLayout.configAgendaPanelIndex),
          );
        } else if (SettingsPanelLayout.isConfigAgendaPanel(index)) {
          panelWidget = SettingsAgendaPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: () =>
                _selectPanel(SettingsPanelLayout.configMoviesSeriesPanelIndex),
            onKeyRight: () =>
                _selectPanel(SettingsPanelLayout.watchPartyPanelIndex),
          );
        } else if (SettingsPanelLayout.isWatchPartyPanel(index)) {
          panelWidget = SettingsWatchPartyPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: () =>
                _selectPanel(SettingsPanelLayout.configAgendaPanelIndex),
            onKeyRight: () =>
                _selectPanel(SettingsPanelLayout.configGeneralPanelIndex),
          );
        } else if (SettingsPanelLayout.isConfigGeneralPanel(index)) {
          panelWidget = SettingsGeneralPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: () =>
                _selectPanel(SettingsPanelLayout.watchPartyPanelIndex),
            onKeyRight: () => _selectPanel(SettingsPanelLayout.aboutPanelIndex),
          );
        } else {
          panelWidget = SettingsAboutPanel(
            focusNode: focusNode,
            initialIndex: itemIndex,
            onSelectedIndexChanged: onItemChanged,
            onKeyLeft: () =>
                _selectPanel(SettingsPanelLayout.configGeneralPanelIndex),
          );
        }

        return panelWidget;
      },
    );
  }
}
