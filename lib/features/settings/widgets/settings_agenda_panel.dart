import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/widgets/dialogs/tv_agenda_time_zone_dialog.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_notify_row.dart';
import 'package:moai3/features/settings/widgets/settings_agenda_snack_duration_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

enum _SettingsAgendaItemType { utcOffset, notifyLead, snackDuration }

/// Panel de Ajustes de la agenda. Una fila abre la pantalla de desfase UTC.
class SettingsAgendaPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsAgendaPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<SettingsAgendaPanel> createState() => SettingsAgendaPanelState();
}

class SettingsAgendaPanelState extends State<SettingsAgendaPanel> {
  final _listKey = GlobalKey<TvWindowedListState<_SettingsAgendaItemType>>();
  late int _selectedIndex = widget.initialIndex;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final clock = context.watch<AgendaClockProvider>();
    final (notifyLeadMinutes, snackDurationSeconds) = context.select(
      (CalendarProvider c) => (c.notifyLeadMinutes, c.snackDurationSeconds),
    );
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
        padding: TvPanelSlots.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: LocaleKeys.settings_agenda_title.tr(),
              subtitle: LocaleKeys.settings_agenda_subtitle.tr(),
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
                        child: TvWindowedList<_SettingsAgendaItemType>(
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
                                  child: switch (item) {
                                    _SettingsAgendaItemType.utcOffset =>
                                      TvSettingsActionRow(
                                        focusNode: focusNode,
                                        icon: MoaiIcons.timeZone,
                                        label: LocaleKeys.settings_agenda_utc
                                            .tr(),
                                        description: LocaleKeys
                                            .settings_agenda_utc_desc
                                            .tr(
                                              namedArgs: {
                                                'zone': clock.zone.nameKey.tr(),
                                                'offset': clock.formattedOffset,
                                              },
                                            ),
                                        onPressed: () {
                                          TvAgendaTimeZoneDialog.show(context);
                                        },
                                        onKeyLeft: widget.onKeyLeft,
                                        onKeyRight: widget.onKeyRight,
                                        onKeyUp: onKeyUp,
                                        onKeyDown: onKeyDown,
                                      ),
                                    _SettingsAgendaItemType.notifyLead =>
                                      SettingsAgendaNotifyRow(
                                        focusNode: focusNode,
                                        selectedMinutes: notifyLeadMinutes,
                                        onChanged: (value) {
                                          context
                                              .read<CalendarProvider>()
                                              .setNotifyLeadMinutes(value);
                                        },
                                        onKeyLeft: widget.onKeyLeft,
                                        onKeyRight: widget.onKeyRight,
                                        onKeyUp: onKeyUp,
                                        onKeyDown: onKeyDown,
                                      ),
                                    _SettingsAgendaItemType.snackDuration =>
                                      SettingsAgendaSnackDurationRow(
                                        focusNode: focusNode,
                                        selectedSeconds: snackDurationSeconds,
                                        onChanged: (value) {
                                          context
                                              .read<CalendarProvider>()
                                              .setSnackDurationSeconds(value);
                                        },
                                        onKeyLeft: widget.onKeyLeft,
                                        onKeyRight: widget.onKeyRight,
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
