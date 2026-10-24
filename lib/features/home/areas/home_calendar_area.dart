import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/calendar/widgets/calendar_events_panel.dart';
import 'package:moai3/features/calendar/widgets/calendar_subscriptions_panel.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Área principal de Calendario Deportivo: Acordeón de 2 paneles (Eventos y Suscripciones).
///
/// Es dueña de sus [FocusNode]; el padre solo recuerda el panel abierto.
class HomeCalendarArea extends StatefulWidget {
  final int initialPanelIndex;
  final ValueChanged<int>? onPanelIndexChanged;
  final VoidCallback onExitLeft;
  final ValueChanged<Channel>? onTuneChannel;

  const HomeCalendarArea({
    super.key,
    this.initialPanelIndex = 0,
    this.onPanelIndexChanged,
    required this.onExitLeft,
    this.onTuneChannel,
  });

  static const icons = [
    MoaiIcons.calendarEvents,
    MoaiIcons.calendarSubscriptions,
  ];

  @override
  State<HomeCalendarArea> createState() => HomeCalendarAreaState();
}

class HomeCalendarAreaState extends HomeAreaState<HomeCalendarArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _eventsFocus = FocusNode(debugLabel: 'calendar_events');
  final _subscriptionsFocus = FocusNode(debugLabel: 'calendar_subscriptions');
  late int _panel = widget.initialPanelIndex;
  int _eventsEntryDayIndex = 0;

  @override
  void dispose() {
    _eventsFocus.dispose();
    _subscriptionsFocus.dispose();
    super.dispose();
  }

  @override
  void requestEntryFocus() => _focus.node(
    _panel == 0 ? _eventsFocus : _subscriptionsFocus,
    immediate: true,
  );

  void _onPanelIndexChanged(int newIndex) {
    if (newIndex == 0 && _panel == 1) {
      // Al cambiar de Suscripciones (panel 1) a Eventos (panel 0), entrar por DOMINGO (col 6)
      _eventsEntryDayIndex = 6;
    } else if (newIndex == 0 && _panel == 0) {
      _eventsEntryDayIndex = 0;
    }
    setState(() => _panel = newIndex);
    widget.onPanelIndexChanged?.call(newIndex);
    requestEntryFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final panelColors = [
      scheme.surface.withValues(alpha: 0.8),
      scheme.surface.withValues(alpha: 0.8),
    ];
    final titles = [
      LocaleKeys.calendar_panel_events_title.tr(),
      LocaleKeys.calendar_panel_subscriptions_title.tr(),
    ];

    return TvAccordionRowPreview(
      panelCount: 2,
      activeIndex: _panel,
      colors: panelColors,
      titles: titles,
      icons: HomeCalendarArea.icons,
      onPanelTap: _onPanelIndexChanged,
      buildExpandedContent: (index, title) {
        if (index == 0) {
          return CalendarEventsPanel(
            focusNode: _eventsFocus,
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
          focusNode: _subscriptionsFocus,
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
