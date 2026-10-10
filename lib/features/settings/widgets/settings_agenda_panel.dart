import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/screens/agenda_utc_offset_screen.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_notify_row.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_snack_duration_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';

enum _SettingsAgendaItemType { utcOffset, notifyLead, snackDuration }

/// Panel de Ajustes de la agenda. Una fila abre la pantalla de desfase UTC.
class SettingsAgendaPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsAgendaPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsAgendaPanel> createState() => SettingsAgendaPanelState();
}

class SettingsAgendaPanelState extends State<SettingsAgendaPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey = GlobalKey<TvWindowedListState<_SettingsAgendaItemType>>();
  int _selectedIndex = 0;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final clock = context.watch<AgendaClockProvider>();
    final calendar = context.watch<CalendarProvider>();
    const items = [
      _SettingsAgendaItemType.utcOffset,
      _SettingsAgendaItemType.notifyLead,
      _SettingsAgendaItemType.snackDuration,
    ];

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(
          left: 4,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: 'settings_agenda_title'.tr(),
              subtitle: 'settings_agenda_subtitle'.tr(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetHeight = (_windowSize * _itemExtent)
                      .clamp(0.0, constraints.maxHeight);
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: targetHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TvWindowedList<_SettingsAgendaItemType>(
                          key: _listKey,
                          items: items,
                          windowSize: _windowSize,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                          },
                          itemBuilder: (
                            context,
                            item,
                            focusNode,
                            local,
                            global,
                            onKeyUp,
                            onKeyDown,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: switch (item) {
                                _SettingsAgendaItemType.utcOffset =>
                                  TvSettingsActionRow(
                                    focusNode: focusNode,
                                    icon: AppIcons.utcOffset(),
                                    iconAccentColor: const Color(0xFF4FC3F7),
                                    label: 'settings_agenda_utc'.tr(),
                                    description: 'settings_agenda_utc_desc'.tr(
                                      namedArgs: {
                                        'zone': clock.zone.nameKey.tr(),
                                        'offset': clock.formattedOffset,
                                      },
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AgendaUtcOffsetScreen(),
                                        ),
                                      );
                                    },
                                    onKeyLeft: widget.onKeyLeft,
                                    onKeyRight: widget.onKeyRight,
                                    onKeyUp: onKeyUp,
                                    onKeyDown: onKeyDown,
                                  ),
                                _SettingsAgendaItemType.notifyLead =>
                                  SettingsAgendaNotifyRow(
                                    focusNode: focusNode,
                                    iconAccentColor: const Color(0xFFFFB74D),
                                    selectedMinutes: calendar.notifyLeadMinutes,
                                    onChanged: calendar.setNotifyLeadMinutes,
                                    onKeyUp: onKeyUp,
                                    onKeyDown: onKeyDown,
                                  ),
                                _SettingsAgendaItemType.snackDuration =>
                                  SettingsAgendaSnackDurationRow(
                                    focusNode: focusNode,
                                    iconAccentColor: const Color(0xFF81C784),
                                    selectedSeconds:
                                        calendar.snackDurationSeconds,
                                    onChanged: calendar.setSnackDurationSeconds,
                                    onKeyUp: onKeyUp,
                                    onKeyDown: onKeyDown,
                                  ),
                              },
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
}
