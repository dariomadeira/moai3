import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/bootstrap/screens/overlap_config_screen.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/plugins/screens/general_plugins_screen.dart';
import 'package:moai3/features/settings/widgets/settings_accent_color_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/widgets/dialogs/tv_weather_location_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

enum _SettingsGeneralItemType {
  plugins,
  overscan,
  weatherLocation,
  darkMode,
  accentColor,
  muteUiSounds,
}

class SettingsGeneralPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsGeneralPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<SettingsGeneralPanel> createState() => SettingsGeneralPanelState();
}

class SettingsGeneralPanelState extends State<SettingsGeneralPanel> {
  final _listKey = GlobalKey<TvWindowedListState<_SettingsGeneralItemType>>();
  late int _selectedIndex = widget.initialIndex;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    final items = <_SettingsGeneralItemType>[
      _SettingsGeneralItemType.plugins,
      _SettingsGeneralItemType.overscan,
      _SettingsGeneralItemType.weatherLocation,
      // Modo oscuro (2026-11-10): por ahora sólo en debug, mientras se arma;
      // al terminarlo se muestra en release también.
      if (kDebugMode) _SettingsGeneralItemType.darkMode,
      _SettingsGeneralItemType.accentColor,
      _SettingsGeneralItemType.muteUiSounds,
    ];

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: TvPanelSlots.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: LocaleKeys.settings_general_title.tr(),
              subtitle: LocaleKeys.settings_general_subtitle.tr(),
              titleShader: HomeClock.timeShader,
            ),
            // Igual que Agenda › Suscripciones: los 6 lugares reparten el
            // alto bajo el encabezado.
            TvPanelSlots.belowHeader,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemExtent = TvPanelSlots.extentFor(
                    constraints.maxHeight,
                  );
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: (TvPanelSlots.count * itemExtent).clamp(
                        0.0,
                        constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TvWindowedList<_SettingsGeneralItemType>(
                          key: _listKey,
                          // La entrada de foco la decide el área (rail →, cambio de panel).
                          focusOnMount: false,
                          items: items,
                          itemExtent: itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                            widget.onSelectedIndexChanged?.call(idx);
                          },
                          itemBuilder:
                              (
                                context,
                                item,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: TvPanelSlots.gap / 2,
                                  ),
                                  child: _buildItem(
                                    context: context,
                                    item: item,
                                    theme: theme,
                                    focusNode: focusNode,
                                    onKeyUp: onKeyUp,
                                    onKeyDown: onKeyDown,
                                  ),
                                );
                              },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required _SettingsGeneralItemType item,
    required ThemeProvider theme,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _SettingsGeneralItemType.plugins:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.extension,
          label: LocaleKeys.settings_general_plugins_title.tr(),
          description: LocaleKeys.settings_general_plugins_desc.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const GeneralPluginsScreen(),
              ),
            );
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.overscan:
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.screenCalibration,
          label: LocaleKeys.settings_general_overscan.tr(),
          description: LocaleKeys.settings_general_overscan_desc.tr(),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    const OverlapConfigScreen(isFirstRun: false),
              ),
            );
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.weatherLocation:
        final weather = context.watch<WeatherProvider>();
        return TvSettingsActionRow(
          focusNode: focusNode,
          icon: MoaiIcons.weather,
          label: LocaleKeys.settings_general_weather_title.tr(),
          description: weather.locationDisplayName,
          onPressed: () {
            TvWeatherLocationDialog.show(context);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.darkMode:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.darkMode,
          label: LocaleKeys.settings_general_dark_mode.tr(),
          description: LocaleKeys.settings_general_dark_mode_desc.tr(),
          value: theme.themeMode == ThemeMode.dark,
          onChanged: (isDark) {
            theme.setDarkMode(isDark);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.accentColor:
        return SettingsAccentColorRow(
          focusNode: focusNode,
          icon: MoaiIcons.palette,
          selectedIndex: theme.accentColorIndex,
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsGeneralItemType.muteUiSounds:
        final muted = context.watch<TvSettingsProvider>().uiSoundsDisabled;
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.volumeOff,
          label: LocaleKeys.settings_general_mute_ui_sounds.tr(),
          description: LocaleKeys.settings_general_mute_ui_sounds_desc.tr(),
          value: muted,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setUiSoundsDisabled(value);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}
