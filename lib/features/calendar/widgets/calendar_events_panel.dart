import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/calendar/calendar_channel_matcher.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

enum _FocusSection {
  header,
  grid,
}

enum _HeaderAction {
  prev,
  current,
  next,
}

/// Panel 0 del acordeón de Calendario: Grilla semanal de 7 días (Lunes a Domingo)
/// con colores sólidos, sin bordes, sin sombras, optimizado para Android TV.
class CalendarEventsPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialDayIndex;
  final ValueChanged<Channel>? onTuneChannel;

  const CalendarEventsPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialDayIndex = 0,
    this.onTuneChannel,
  });

  @override
  State<CalendarEventsPanel> createState() => CalendarEventsPanelState();
}

class CalendarEventsPanelState extends State<CalendarEventsPanel> {
  /// Offset de semana:
  /// -1 = semana anterior (límite inferior estricto)
  ///  0 = semana actual
  /// +1, +2... = semanas futuras
  int _weekOffset = 0;

  /// Sección con foco activo: header o grid
  _FocusSection _focusSection = _FocusSection.grid;

  /// Índice de acción activa en el header
  int _headerActionIndex = 0;

  /// Día de la semana seleccionado (0 = Lunes, ..., 6 = Domingo)
  late int _selectedDayIndex;

  static const int _windowSize = 4;

  /// Índice del evento seleccionado por cada día de la semana (índice global)
  final Map<int, int> _selectedEventIndices = {
    0: 0,
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 0,
    6: 0,
  };

  /// Inicio de la ventana visible de hasta 4 tarjetas por cada día de la semana
  final Map<int, int> _windowStarts = {
    0: 0,
    1: 0,
    2: 0,
    3: 0,
    4: 0,
    5: 0,
    6: 0,
  };

  bool _hadFocus = false;
  Timer? _tickerTimer;

  /// Enfocar explícitamente desde la izquierda (Lunes / col 0)
  void focusFromLeft() {
    setState(() {
      _focusSection = _FocusSection.grid;
      _selectedDayIndex = 0;
    });
    widget.focusNode.requestFocus();
  }

  /// Enfocar explícitamente desde la derecha (Domingo / col 6)
  void focusFromRight() {
    setState(() {
      _focusSection = _FocusSection.grid;
      _selectedDayIndex = 6;
    });
    widget.focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = widget.initialDayIndex.clamp(0, 6);
    _focusSection = _FocusSection.grid;
    _hadFocus = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocusChanged);

    // Ticker periódico: mientras el panel de calendario esté en pantalla,
    // redibuja cada 30 segundos para reflejar en tiempo real el paso de partidos
    // a EN VIVO o a FINALIZADO sin necesidad de tocar ningún botón.
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CalendarEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDayIndex != widget.initialDayIndex) {
      _selectedDayIndex = widget.initialDayIndex.clamp(0, 6);
      _focusSection = _FocusSection.grid;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
      _hadFocus = widget.focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus && !_hadFocus) {
      setState(() {
        _focusSection = _FocusSection.grid;
      });
    }
    _hadFocus = widget.focusNode.hasFocus;
  }

  List<_HeaderAction> _getAvailableHeaderActions() {
    final actions = <_HeaderAction>[];
    if (_weekOffset > -1) {
      actions.add(_HeaderAction.prev);
    }
    if (_weekOffset != 0) {
      actions.add(_HeaderAction.current);
    }
    actions.add(_HeaderAction.next);
    return actions;
  }



  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, CalendarProvider calendar, List<DateTime> days) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_focusSection == _FocusSection.header) {
      final actions = _getAvailableHeaderActions();
      if (_headerActionIndex >= actions.length) {
        _headerActionIndex = actions.length - 1;
      }

      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_headerActionIndex > 0) {
          setState(() => _headerActionIndex--);
          return KeyEventResult.handled;
        } else {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        if (_headerActionIndex < actions.length - 1) {
          setState(() => _headerActionIndex++);
          return KeyEventResult.handled;
        } else {
          widget.onKeyRight();
          return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _focusSection = _FocusSection.grid);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space) {
        _executeHeaderAction(actions[_headerActionIndex]);
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

    // _focusSection == _FocusSection.grid
    final currentDay = days[_selectedDayIndex];
    final dayEvents = calendar.getEventsForDay(currentDay);
    final currentEventIndex = (_selectedEventIndices[_selectedDayIndex] ?? 0).clamp(
      0,
      dayEvents.isEmpty ? 0 : dayEvents.length - 1,
    );

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_selectedDayIndex > 0) {
        setState(() {
          _selectedDayIndex--;
          _clampCurrentEventIndex(calendar, days);
        });
        return KeyEventResult.handled;
      } else {
        widget.onKeyLeft();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (_selectedDayIndex < 6) {
        setState(() {
          _selectedDayIndex++;
          _clampCurrentEventIndex(calendar, days);
        });
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
          setState(() {
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex - 1;
          });
          return KeyEventResult.handled;
        }

        if (currentEventIndex > 0) {
          const anchorSlot = _windowSize - 2;
          final maxStart = (dayEvents.length - _windowSize).clamp(0, dayEvents.length);
          final target = currentEventIndex - 1;
          final newStart = (target - anchorSlot).clamp(0, maxStart);
          setState(() {
            _windowStarts[_selectedDayIndex] = newStart;
            _selectedEventIndices[_selectedDayIndex] = target;
          });
          return KeyEventResult.handled;
        }
      }

      // Subir al encabezado
      setState(() {
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
        final visibleCount = (dayEvents.length - start).clamp(0, _windowSize);
        final local = currentEventIndex - start;
        final lastLocal = visibleCount - 1;

        if (local < lastLocal) {
          setState(() {
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex + 1;
          });
          return KeyEventResult.handled;
        }

        if (currentEventIndex < dayEvents.length - 1) {
          final maxStart = (dayEvents.length - _windowSize).clamp(0, dayEvents.length);
          final newStart = (currentEventIndex - 1).clamp(0, maxStart);
          setState(() {
            _windowStarts[_selectedDayIndex] = newStart;
            _selectedEventIndices[_selectedDayIndex] = currentEventIndex + 1;
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (dayEvents.isNotEmpty && currentEventIndex < dayEvents.length) {
        final ev = dayEvents[currentEventIndex];
        if (ev.status == CalendarEventStatus.finished) {
          // Evento concluido: no-op estricto (no abre nada, no interrumpe al usuario)
          return KeyEventResult.handled;
        }
        _showEventDetails(context, ev);
        return KeyEventResult.handled;
      }
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
    final maxStart = (dayEvents.length - _windowSize).clamp(0, dayEvents.length);
    if (currentIndex < start) {
      start = currentIndex;
    } else if (currentIndex >= start + _windowSize) {
      start = (currentIndex - _windowSize + 1).clamp(0, maxStart);
    }
    _windowStarts[_selectedDayIndex] = start.clamp(0, maxStart);
  }

  void _executeHeaderAction(_HeaderAction action) {
    setState(() {
      switch (action) {
        case _HeaderAction.prev:
          if (_weekOffset > -1) {
            _weekOffset--;
          }
          break;
        case _HeaderAction.current:
          _weekOffset = 0;
          final todayWeekday = DateTime.now().weekday;
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
  }

  String _formatWeekRange(DateTime monday, DateTime sunday) {
    const months = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    if (monday.month == sunday.month) {
      return '${monday.day} - ${sunday.day} ${months[monday.month]} ${sunday.year}';
    } else if (monday.year == sunday.year) {
      return '${monday.day} ${months[monday.month]} - ${sunday.day} ${months[sunday.month]} ${sunday.year}';
    } else {
      return '${monday.day} ${months[monday.month]} ${monday.year} - ${sunday.day} ${months[sunday.month]} ${sunday.year}';
    }
  }

  void _showEventDetails(BuildContext context, CalendarEvent event) {
    if (event.status == CalendarEventStatus.finished) {
      return;
    }
    final isLive = event.status == CalendarEventStatus.live;

    showTvGeneralDialog<void>(
      context: context,
      barrierLabel: 'calendar_dialog_close'.tr(),
      builder: (dialogContext) {
        return _CalendarEventDialogContent(
          event: event,
          isLive: isLive,
          onTuneChannel: widget.onTuneChannel,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final calendar = context.watch<CalendarProvider>();
    final isPanelFocused = widget.focusNode.hasFocus;

    final days = CalendarProvider.getDaysForWeekOffset(_weekOffset);
    final monday = days.first;
    final sunday = days.last;

    final headerActions = _getAvailableHeaderActions();
    if (_headerActionIndex >= headerActions.length) {
      _headerActionIndex = headerActions.length - 1;
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, calendar, days),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= HEADER SUPERIOR =================
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
            child: Row(
              children: [
                // Título e intervalo de fechas
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatWeekRange(monday, sunday),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.display(
                            context,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Botones de navegación semanal
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(headerActions.length, (idx) {
                    final action = headerActions[idx];
                    final isFocused = isPanelFocused &&
                        _focusSection == _FocusSection.header &&
                        _headerActionIndex == idx;

                    switch (action) {
                      case _HeaderAction.prev:
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _HeaderButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'calendar_week_nav_prev'.tr(),
                            isFocused: isFocused,
                            onTap: () {
                              _headerActionIndex = idx;
                              _executeHeaderAction(action);
                              widget.focusNode.requestFocus();
                            },
                          ),
                        );
                      case _HeaderAction.current:
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _HeaderButton(
                            icon: Icons.today_rounded,
                            label: 'calendar_week_current'.tr(),
                            isFocused: isFocused,
                            onTap: () {
                              _headerActionIndex = idx;
                              _executeHeaderAction(action);
                              widget.focusNode.requestFocus();
                            },
                          ),
                        );
                      case _HeaderAction.next:
                        return _HeaderButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'calendar_week_nav_next'.tr(),
                          isFocused: isFocused,
                          onTap: () {
                            _headerActionIndex = idx;
                            _executeHeaderAction(action);
                            widget.focusNode.requestFocus();
                          },
                        );
                    }
                  }),
                ),
              ],
            ),
          ),

          // ================= 7 COLUMNAS SEMANALES =================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(7, (dayIdx) {
                  final day = days[dayIdx];
                  final dayEvents = calendar.getEventsForDay(day);
                  final isDayColumnSelected = isPanelFocused &&
                      _focusSection == _FocusSection.grid &&
                      _selectedDayIndex == dayIdx;

                  final currentEventIndex = (_selectedEventIndices[dayIdx] ?? 0).clamp(
                    0,
                    dayEvents.isEmpty ? 0 : dayEvents.length - 1,
                  );

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: _DayColumn(
                        day: day,
                        dayIndex: dayIdx,
                        events: dayEvents,
                        isColumnFocused: isDayColumnSelected,
                        selectedEventIndex: currentEventIndex,
                        windowStart: _windowStarts[dayIdx] ?? 0,
                        windowSize: _windowSize,
                        onSelectEvent: (eventIdx) {
                          setState(() {
                            _focusSection = _FocusSection.grid;
                            _selectedDayIndex = dayIdx;
                            _selectedEventIndices[dayIdx] = eventIdx;
                          });
                          widget.focusNode.requestFocus();
                          if (eventIdx < dayEvents.length) {
                            final ev = dayEvents[eventIdx];
                            if (ev.status != CalendarEventStatus.finished) {
                              _showEventDetails(context, ev);
                            }
                          }
                        },
                        onSelectColumn: () {
                          setState(() {
                            _focusSection = _FocusSection.grid;
                            _selectedDayIndex = dayIdx;
                          });
                          widget.focusNode.requestFocus();
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón con color sólido y sin bordes para el header
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isFocused;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    this.label,
    this.tooltip,
    required this.isFocused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final bgColor = isFocused ? scheme.primary : scheme.surfaceContainerHigh;
    final fgColor = isFocused ? scheme.onPrimary : scheme.onSurface;

    return Tooltip(
      message: tooltip ?? label ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fgColor),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: MoaiText.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Columna de un día de la semana con colores sólidos y sin bordes
class _DayColumn extends StatelessWidget {
  final DateTime day;
  final int dayIndex;
  final List<CalendarEvent> events;
  final bool isColumnFocused;
  final int selectedEventIndex;
  final int windowStart;
  final int windowSize;
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
    required this.onSelectEvent,
    required this.onSelectColumn,
  });

  static const _dayNames = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  bool get _isToday {
    final now = DateTime.now();
    return now.year == day.year && now.month == day.month && now.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dayLabel = _dayNames[(day.weekday - 1).clamp(0, 6)];
    final isToday = _isToday;

    // Colores sólidos para el encabezado del día
    final Color headerBg;
    final Color headerDayNameColor;
    final Color headerDayNumberColor;

    if (isToday) {
      if (isColumnFocused) {
        headerBg = scheme.primary;
        headerDayNameColor = scheme.onPrimary;
        headerDayNumberColor = scheme.onPrimary;
      } else {
        headerBg = scheme.primaryContainer;
        headerDayNameColor = scheme.primary;
        headerDayNumberColor = scheme.onPrimaryContainer;
      }
    } else {
      if (isColumnFocused) {
        headerBg = scheme.secondaryContainer;
        headerDayNameColor = scheme.onSecondaryContainer;
        headerDayNumberColor = scheme.onSecondaryContainer;
      } else {
        headerBg = scheme.surfaceContainer;
        headerDayNameColor = scheme.onSurfaceVariant;
        headerDayNumberColor = scheme.onSurface;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del día con color sólido y sin bordes
        GestureDetector(
          onTap: onSelectColumn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    fontSize: 11,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                    color: headerDayNameColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: MoaiText.display(
                    context,
                    fontSize: 15,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                    color: headerDayNumberColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Lista de eventos por ventana (máximo 4 visibles) o estado vacío
        Expanded(
          child: events.isEmpty
              ? _buildEmptyState(context)
              : _buildWindowedList(context),
        ),
      ],
    );
  }

  Widget _buildWindowedList(BuildContext context) {
    const gap = 6.0;
    final start = windowStart.clamp(0, (events.length - windowSize).clamp(0, events.length));
    final count = (events.length - start).clamp(0, windowSize);
    final visibleEvents = events.sublist(start, start + count);
    final scheme = context.scheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final hasMoreEvents = events.length > windowSize;
        final canScrollUp = windowStart > 0;
        final canScrollDown = windowStart + windowSize < events.length;

        // Si no hay más eventos que el tamaño de ventana, se usa toda la altura
        if (!hasMoreEvents) {
          final slotHeight = (totalHeight - ((windowSize - 1) * gap)) / windowSize;
          final safeSlotHeight = slotHeight.clamp(30.0, 150.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(count, (i) {
              final globalIndex = start + i;
              final event = visibleEvents[i];
              final isItemFocused = isColumnFocused && selectedEventIndex == globalIndex;

              return Padding(
                padding: EdgeInsets.only(bottom: i < count - 1 ? gap : 0),
                child: _CalendarEventGridCard(
                  event: event,
                  isFocused: isItemFocused,
                  height: safeSlotHeight,
                  onTap: () => onSelectEvent(globalIndex),
                ),
              );
            }),
          );
        }

        // Variación con más eventos: se reserva espacio exclusivo arriba y abajo para los pills
        const indicatorAreaHeight = 22.0;
        final availableHeight = totalHeight - (indicatorAreaHeight * 2);
        final slotHeight = (availableHeight - ((windowSize - 1) * gap)) / windowSize;
        final safeSlotHeight = slotHeight.clamp(30.0, 150.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Espacio superior reservado con mayor separación
            SizedBox(
              height: indicatorAreaHeight,
              child: canScrollUp
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 12,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    )
                  : null,
            ),
            // Tarjetas visibles
            ...List.generate(count, (i) {
              final globalIndex = start + i;
              final event = visibleEvents[i];
              final isItemFocused = isColumnFocused && selectedEventIndex == globalIndex;

              return Padding(
                padding: EdgeInsets.only(bottom: i < count - 1 ? gap : 0),
                child: _CalendarEventGridCard(
                  event: event,
                  isFocused: isItemFocused,
                  height: safeSlotHeight,
                  onTap: () => onSelectEvent(globalIndex),
                ),
              );
            }),
            // Espacio inferior reservado con mayor separación
            SizedBox(
              height: indicatorAreaHeight,
              child: canScrollDown
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 12,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = isColumnFocused;

    return GestureDetector(
      onTap: onSelectColumn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isFocused ? scheme.secondaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 24,
              color: isFocused ? scheme.onSecondaryContainer : scheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'calendar_no_events_day'.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: isFocused ? FontWeight.w700 : FontWeight.w500,
                color: isFocused ? scheme.onSecondaryContainer : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta individual de evento con colores 100% sólidos, sin bordes y sin sombras.
/// Solo muestra: Ícono + Hora + Título del evento (sin info de canales ni competiciones).
class _CalendarEventGridCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isFocused;
  final double height;
  final VoidCallback onTap;

  const _CalendarEventGridCard({
    required this.event,
    required this.isFocused,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = event.status == CalendarEventStatus.live;
    final isFinished = event.status == CalendarEventStatus.finished;
    final sportIcon = CalendarProvider.getSubscriptionIcon(event.subscriptionId);

    // Paleta de colores adaptativa según estado y foco
    final Color bgColor;
    final Color fgColor;
    final Color subColor;

    if (isFinished) {
      bgColor = isFocused
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLowest;
      fgColor = isFocused ? scheme.onSurface : scheme.outline;
      subColor = scheme.outline;
    } else {
      bgColor = isFocused
          ? scheme.primary
          : (isLive
              ? scheme.surfaceContainerHighest
              : scheme.surfaceContainerHigh);
      fgColor = isFocused ? scheme.onPrimary : scheme.onSurface;
      subColor = isFocused ? scheme.onPrimary : scheme.onSurfaceVariant;
    }

    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: isFinished ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila superior: Ícono del deporte según la suscripción + Hora + Micro-Badge en vivo M3
                // Protegido con FittedBox para prevenir desbordamientos en cualquier ancho o transición
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          sportIcon,
                          size: 11.5,
                          color: isFinished ? fgColor : subColor,
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          event.formattedTime,
                          style: MoaiText.display(
                            context,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: fgColor,
                          ),
                        ),
                        if (isFinished) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 11,
                            color: fgColor,
                          ),
                        ] else if (isLive) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isFocused
                                  ? scheme.surface
                                  : scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'calendar_status_live'.tr(),
                              style: MoaiText.body(
                                context,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: isFocused
                                    ? scheme.primary
                                    : scheme.onPrimaryContainer,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),



                const SizedBox(height: 4),

                // Título del evento con fuente compacta (sin competición ni emisora)
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: fgColor,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

class _CalendarEventDialogContent extends StatefulWidget {
  final CalendarEvent event;
  final bool isLive;
  final ValueChanged<Channel>? onTuneChannel;

  const _CalendarEventDialogContent({
    required this.event,
    required this.isLive,
    this.onTuneChannel,
  });

  @override
  State<_CalendarEventDialogContent> createState() =>
      _CalendarEventDialogContentState();
}

class _CalendarEventDialogContentState
    extends State<_CalendarEventDialogContent> {
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'dialog_close');
  final _listKey = GlobalKey<TvWindowedListState<Channel>>();
  List<Channel> _matchingChannels = const [];

  @override
  void initState() {
    super.initState();
    final allChannels = context.read<ChannelProvider>().allChannels;
    _matchingChannels = CalendarChannelMatcher.findMatchingChannels(
      widget.event,
      allChannels,
      maxResults: 16,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Si el evento está en vivo y hay canales disponibles, enfocar el primer canal; de lo contrario cerrar
      if (widget.isLive && _matchingChannels.isNotEmpty) {
        _listKey.currentState?.ensureVisible(0, requestFocus: true);
      } else {
        _closeFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _closeFocusNode.dispose();
    super.dispose();
  }

  void _tuneChannel(Channel channel) {
    Navigator.of(context).pop();
    if (widget.onTuneChannel != null) {
      widget.onTuneChannel!(channel);
    } else {
      context.read<ChannelProvider>().selectChannel(channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final scheme = context.scheme;
    final hasChannels = _matchingChannels.isNotEmpty;

    final detailsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildModalDetailRow(
          context,
          icon: Icons.schedule_rounded,
          label: 'calendar_event_time'.tr(),
          value: '${event.formattedDate} • ${event.formattedTime} hs',
        ),
        const SizedBox(height: 12),
        _buildModalDetailRow(
          context,
          icon: Icons.sports_rounded,
          label: 'calendar_event_sport'.tr(),
          value: event.sessionType ?? event.competition,
        ),
        if (event.broadcaster != null && event.broadcaster!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildModalDetailRow(
            context,
            icon: Icons.tv_rounded,
            label: 'calendar_event_broadcaster'.tr(),
            value: event.broadcaster!,
          ),
        ],
      ],
    );

    final contentWidget = hasChannels
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna 1: Datos del evento
              Expanded(
                flex: 10,
                child: detailsColumn,
              ),
              const SizedBox(width: 20),
              // Columna 2: Panel contenedor con borde redondeado y lista oficial de canales
              Expanded(
                flex: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TvWindowedList<Channel>(
                    key: _listKey,
                    items: _matchingChannels,
                    windowSize: 4,
                    itemExtent: TvLayoutConstants.channelItemHeight,
                    showScrollDots: true,
                    itemBuilder: (context, ch, focusNode, local, global, onKeyUp, onKeyDown) {
                      return NewChannelCard(
                        key: ValueKey(ch.id),
                        channel: ch,
                        isSelected: false,
                        focusNode: focusNode,
                        onKeyLeft: () => _closeFocusNode.requestFocus(),
                        onKeyUp: onKeyUp,
                        onKeyDown: () {
                          if (global >= _matchingChannels.length - 1) {
                            _closeFocusNode.requestFocus();
                          } else {
                            onKeyDown();
                          }
                        },
                        onTap: () => _tuneChannel(ch),
                      );
                    },
                  ),
                ),
              ),
            ],
          )
        : detailsColumn;

    return TvDialog(
      width: hasChannels ? 800 : 480,
      icon: Icons.event_note_rounded,
      title: event.title,
      subtitle: event.competition,
      trailingHeader: widget.isLive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'calendar_status_live'.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : null,
      content: contentWidget,
      actions: [
        Focus(
          onKeyEvent: (node, keyEvent) {
            if (keyEvent is KeyDownEvent && hasChannels) {
              if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
                  keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
                _listKey.currentState?.ensureVisible(0, requestFocus: true);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: TvDialogButton(
            focusNode: _closeFocusNode,
            label: 'calendar_dialog_close'.tr(),
            variant: TvDialogButtonVariant.neutral,
            autofocus: !widget.isLive || !hasChannels,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildModalDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: MoaiText.body(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


