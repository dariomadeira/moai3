part of '../calendar_events_panel.dart';

/// Columna de un día de la Agenda: [TvWeekDayColumn] (compartida con
/// Descuentos) con las tarjetas de sus eventos.
class _DayColumn extends StatelessWidget {
  final DateTime day;
  final int dayIndex;
  final List<CalendarEvent> events;
  final bool isColumnFocused;
  final int selectedEventIndex;
  final int windowStart;
  final int windowSize;
  final bool actionPressed;
  final ValueChanged<int> onSelectEvent;
  final VoidCallback onSelectColumn;

  const _DayColumn({
    required this.day,
    required this.dayIndex,
    required this.events,
    required this.isColumnFocused,
    required this.selectedEventIndex,
    required this.windowStart,
    required this.windowSize,
    required this.actionPressed,
    required this.onSelectEvent,
    required this.onSelectColumn,
  });

  bool get _isToday {
    final now = ArgentinaTime.now();
    return now.year == day.year && now.month == day.month && now.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    return TvWeekDayColumn(
      weekdayLabel: MoaiFormats.weekdayShort(day.weekday),
      dayNumber: day.day,
      isToday: _isToday,
      itemCount: events.length,
      isColumnFocused: isColumnFocused,
      selectedIndex: selectedEventIndex,
      windowStart: windowStart,
      windowSize: windowSize,
      emptyIcon: MoaiIcons.calendarEmptyDay,
      emptyText: LocaleKeys.calendar_no_events_day.tr(),
      onSelectColumn: onSelectColumn,
      itemBuilder: (context, index, isFocused, height) =>
          _CalendarEventGridCard(
            event: events[index],
            isFocused: isFocused,
            actionPressed: isFocused && actionPressed,
            height: height,
            onTap: () => onSelectEvent(index),
          ),
    );
  }
}
