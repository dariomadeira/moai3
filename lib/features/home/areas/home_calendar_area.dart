import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/calendar/widgets/calendar_events_panel.dart';
import 'package:moai3/features/calendar/widgets/calendar_subscriptions_panel.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';

/// Área principal de Calendario Deportivo: Acordeón de 2 paneles (Eventos y Suscripciones).
class HomeCalendarArea extends StatefulWidget {
  final int activePanelIndex;
  final FocusNode eventsPanelFocus;
  final FocusNode subscriptionsPanelFocus;
  final ValueChanged<int> onPanelIndexChanged;
  final VoidCallback onExitLeft;
  final ValueChanged<Channel>? onTuneChannel;

  const HomeCalendarArea({
    super.key,
    required this.activePanelIndex,
    required this.eventsPanelFocus,
    required this.subscriptionsPanelFocus,
    required this.onPanelIndexChanged,
    required this.onExitLeft,
    this.onTuneChannel,
  });

  static const icons = [
    Icons.calendar_month_outlined,
    Symbols.calendar_add_on,
  ];

  @override
  State<HomeCalendarArea> createState() => _HomeCalendarAreaState();
}

class _HomeCalendarAreaState extends State<HomeCalendarArea> {
  int _eventsEntryDayIndex = 0;

  void _onPanelIndexChanged(int newIndex) {
    if (newIndex == 0 && widget.activePanelIndex == 1) {
      // Al cambiar de Suscripciones (panel 1) a Eventos (panel 0), entrar por DOMINGO (col 6)
      _eventsEntryDayIndex = 6;
    } else if (newIndex == 0 && widget.activePanelIndex == 0) {
      _eventsEntryDayIndex = 0;
    }
    widget.onPanelIndexChanged(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final panelColors = [
      scheme.surface,
      scheme.surface,
    ];
    final titles = [
      'calendar_panel_events_title'.tr(),
      'calendar_panel_subscriptions_title'.tr(),
    ];

    return TvAccordionRow(
      panelCount: 2,
      activeIndex: widget.activePanelIndex,
      colors: panelColors,
      titles: titles,
      icons: HomeCalendarArea.icons,
      onPanelTap: _onPanelIndexChanged,
      buildExpandedContent: (index, title) {
        if (index == 0) {
          return CalendarEventsPanel(
            focusNode: widget.eventsPanelFocus,
            initialDayIndex: _eventsEntryDayIndex,
            onTuneChannel: widget.onTuneChannel,
            onKeyLeft: () {
              setState(() {
                _eventsEntryDayIndex = 0;
              });
              widget.onExitLeft();
            },
            onKeyRight: () {
              setState(() {
                _eventsEntryDayIndex = 6;
              });
              _onPanelIndexChanged(1);
            },
          );
        }

        return CalendarSubscriptionsPanel(
          focusNode: widget.subscriptionsPanelFocus,
          onKeyLeft: () {
            setState(() {
              _eventsEntryDayIndex = 6;
            });
            _onPanelIndexChanged(0);
          },
        );
      },
    );
  }
}
