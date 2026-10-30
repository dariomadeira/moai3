part of '../calendar_events_panel.dart';

/// Teclas del D-pad y acciones de la cabecera (semana anterior/actual/siguiente).
extension _CalendarEventsKeys on CalendarEventsPanelState {
  List<_HeaderAction> _getAvailableHeaderActions() {
    final actions = <_HeaderAction>[_HeaderAction.refresh];
    if (_weekOffset > -1) {
      actions.add(_HeaderAction.prev);
    }
    if (_weekOffset != 0) {
      actions.add(_HeaderAction.current);
    }
    actions.add(_HeaderAction.next);
    return actions;
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    CalendarProvider calendar,
    List<DateTime> days,
  ) {
    final key = event.logicalKey;
    final isAction = TvKeyHandler.isActionKey(key);

    if (_focusSection == _FocusSection.grid && isAction) {
      if (event is KeyDownEvent) {
        if (!_gridActionPressed) {
          _update(() => _gridActionPressed = true);
        }
        return KeyEventResult.handled;
      }
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (event is KeyUpEvent && _gridActionPressed) {
        _update(() => _gridActionPressed = false);
        final currentDay = days[_selectedDayIndex];
        final dayEvents = calendar.getEventsForDay(currentDay);
        final currentEventIndex =
            (_selectedEventIndices[_selectedDayIndex] ?? 0).clamp(
              0,
              dayEvents.isEmpty ? 0 : dayEvents.length - 1,
            );
        if (dayEvents.isNotEmpty && currentEventIndex < dayEvents.length) {
          _showEventDetails(context, dayEvents[currentEventIndex]);
        }
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_gridActionPressed) {
      _update(() => _gridActionPressed = false);
    }

    if (_focusSection == _FocusSection.header) {
      final actions = _getAvailableHeaderActions();
      if (_headerActionIndex >= actions.length) {
        _headerActionIndex = actions.length - 1;
      }

      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_headerActionIndex > 0) {
          _update(() => _headerActionIndex--);
          return KeyEventResult.handled;
        } else {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        if (_headerActionIndex < actions.length - 1) {
          _update(() => _headerActionIndex++);
          return KeyEventResult.handled;
        } else {
          widget.onKeyRight();
          return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        _update(() => _focusSection = _FocusSection.grid);
        return KeyEventResult.handled;
      }

      if (TvKeyHandler.isActionKey(key)) {
        final action = actions[_headerActionIndex];
        if (action == _HeaderAction.refresh) {
          _refreshCalendar(calendar);
        } else {
          _executeHeaderAction(action);
        }
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    // _focusSection == _FocusSection.grid
    final currentDay = days[_selectedDayIndex];
    final dayEvents = calendar.getEventsForDay(currentDay);
    final currentEventIndex = (_selectedEventIndices[_selectedDayIndex] ?? 0)
        .clamp(0, dayEvents.isEmpty ? 0 : dayEvents.length - 1);

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_selectedDayIndex > 0) {
        _update(() {
          _selectedDayIndex--;
          _clampCurrentEventIndex(calendar, days);
        });
        widget.onDayChanged?.call(_selectedDayIndex);
        widget.onEventIndexChanged?.call(
          _selectedEventIndices[_selectedDayIndex] ?? 0,
        );
        return KeyEventResult.handled;
      } else {
        widget.onKeyLeft();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_selectedDayIndex < 6) {
        _update(() {
          _selectedDayIndex++;
          _clampCurrentEventIndex(calendar, days);
        });
        widget.onDayChanged?.call(_selectedDayIndex);
        widget.onEventIndexChanged?.call(
          _selectedEventIndices[_selectedDayIndex] ?? 0,
        );
        return KeyEventResult.handled;
      } else {
        widget.onKeyRight();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (dayEvents.isNotEmpty) {
        final start = _windowStarts[_selectedDayIndex] ?? 0;
        final local = currentEventIndex - start;

        if (local > 0) {
          _update(() {
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex - 1;
          });
          widget.onEventIndexChanged?.call(
            _selectedEventIndices[_selectedDayIndex] ?? 0,
          );
          return KeyEventResult.handled;
        }

        if (currentEventIndex > 0) {
          const anchorSlot = CalendarEventsPanelState._windowSize - 2;
          final maxStart =
              (dayEvents.length - CalendarEventsPanelState._windowSize).clamp(
                0,
                dayEvents.length,
              );
          final target = currentEventIndex - 1;
          final newStart = (target - anchorSlot).clamp(0, maxStart);
          _update(() {
            _windowStarts[_selectedDayIndex] = newStart;
            _selectedEventIndices[_selectedDayIndex] = target;
          });
          widget.onEventIndexChanged?.call(
            _selectedEventIndices[_selectedDayIndex] ?? 0,
          );
          return KeyEventResult.handled;
        }
      }

      // Subir al encabezado
      _update(() {
        _focusSection = _FocusSection.header;
        final actions = _getAvailableHeaderActions();
        if (actions.contains(_HeaderAction.current)) {
          _headerActionIndex = actions.indexOf(_HeaderAction.current);
        } else {
          _headerActionIndex = 0;
        }
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (dayEvents.isNotEmpty) {
        final start = _windowStarts[_selectedDayIndex] ?? 0;
        final visibleCount = (dayEvents.length - start).clamp(
          0,
          CalendarEventsPanelState._windowSize,
        );
        final local = currentEventIndex - start;
        final lastLocal = visibleCount - 1;

        if (local < lastLocal) {
          _update(() {
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex + 1;
          });
          widget.onEventIndexChanged?.call(
            _selectedEventIndices[_selectedDayIndex] ?? 0,
          );
          return KeyEventResult.handled;
        }

        if (currentEventIndex < dayEvents.length - 1) {
          final maxStart =
              (dayEvents.length - CalendarEventsPanelState._windowSize).clamp(
                0,
                dayEvents.length,
              );
          final newStart = (currentEventIndex - 1).clamp(0, maxStart);
          _update(() {
            _windowStarts[_selectedDayIndex] = newStart;
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex + 1;
          });
          widget.onEventIndexChanged?.call(
            _selectedEventIndices[_selectedDayIndex] ?? 0,
          );
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _clampCurrentEventIndex(CalendarProvider calendar, List<DateTime> days) {
    final dayEvents = calendar.getEventsForDay(days[_selectedDayIndex]);
    if (dayEvents.isEmpty) {
      _selectedEventIndices[_selectedDayIndex] = 0;
      _windowStarts[_selectedDayIndex] = 0;
      return;
    }
    final currentIndex = (_selectedEventIndices[_selectedDayIndex] ?? 0).clamp(
      0,
      dayEvents.length - 1,
    );
    _selectedEventIndices[_selectedDayIndex] = currentIndex;

    var start = _windowStarts[_selectedDayIndex] ?? 0;
    final maxStart = (dayEvents.length - CalendarEventsPanelState._windowSize)
        .clamp(0, dayEvents.length);
    if (currentIndex < start) {
      start = currentIndex;
    } else if (currentIndex >= start + CalendarEventsPanelState._windowSize) {
      start = (currentIndex - CalendarEventsPanelState._windowSize + 1).clamp(
        0,
        maxStart,
      );
    }
    _windowStarts[_selectedDayIndex] = start.clamp(0, maxStart);
  }

  void _refreshCalendar(CalendarProvider calendar) {
    if (calendar.isLoading) return;
    calendar.refreshEvents(force: true);
  }

  void _executeHeaderAction(_HeaderAction action) {
    _update(() {
      switch (action) {
        case _HeaderAction.refresh:
          return;
        case _HeaderAction.prev:
          if (_weekOffset > -1) {
            _weekOffset--;
          }
          break;
        case _HeaderAction.current:
          _weekOffset = 0;
          final todayWeekday = ArgentinaTime.now().weekday;
          _selectedDayIndex = (todayWeekday - 1).clamp(0, 6);
          break;
        case _HeaderAction.next:
          _weekOffset++;
          break;
      }
      for (var i = 0; i < 7; i++) {
        _selectedEventIndices[i] = 0;
        _windowStarts[i] = 0;
      }
      final actions = _getAvailableHeaderActions();
      _headerActionIndex = _headerActionIndex.clamp(0, actions.length - 1);
    });
    widget.onDayChanged?.call(_selectedDayIndex);
    widget.onEventIndexChanged?.call(
      _selectedEventIndices[_selectedDayIndex] ?? 0,
    );
  }

  void _showEventDetails(BuildContext context, CalendarEvent event) {
    showCalendarEventDetails(
      context,
      event,
      onTuneChannel: widget.onTuneChannel,
    );
  }
}
