import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/features/calendar/widgets/calendar_event_details_dialog.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/widgets/week/tv_week_grid.dart';

part 'calendar_events/calendar_events_keys.dart';
part 'calendar_events/calendar_header_button.dart';
part 'calendar_events/calendar_day_column.dart';
part 'calendar_events/calendar_event_grid_card.dart';

enum _FocusSection { header, grid }

enum _HeaderAction { refresh, prev, current, next }

/// Panel 0 del acordeón de Calendario: grilla semanal de 7 días (lunes a domingo).
class CalendarEventsPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialDayIndex;
  final int initialEventIndex;
  final ValueChanged<int>? onDayChanged;
  final ValueChanged<int>? onEventIndexChanged;
  final ValueChanged<Channel>? onTuneChannel;

  const CalendarEventsPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialDayIndex = 0,
    this.initialEventIndex = 0,
    this.onDayChanged,
    this.onEventIndexChanged,
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

  @visibleForTesting
  int get debugSelectedDay => _selectedDayIndex;

  @visibleForTesting
  bool get debugInHeader => _focusSection == _FocusSection.header;

  static const int _windowSize = 4;

  /// OK/Enter del D-pad sobre una tarjeta (para el scale de pulso).
  bool _gridActionPressed = false;

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

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = widget.initialDayIndex.clamp(0, 6);
    _selectedEventIndices[_selectedDayIndex] = widget.initialEventIndex;
    if (widget.initialEventIndex >= _windowSize) {
      _windowStarts[_selectedDayIndex] =
          widget.initialEventIndex - _windowSize + 1;
    }
    _focusSection = _FocusSection.grid;
    _hadFocus = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocusChanged);

    // Ticker periódico: mientras el panel de calendario esté en pantalla,
    // redibuja cada 30 segundos para reflejar en tiempo real el paso de partidos
    // a EN VIVO o a FINALIZADO sin necesidad de tocar ningún botón.
    // Con el panel cerrado en el acordeón (TickerMode apagado) no redibuja.
    _tickerTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && TickerMode.getValuesNotifier(context).value.enabled) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CalendarEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cada cambio de día se avisa al área (onDayChanged), así que el área
    // pasa el día elegido salvo que pida otro (lunes al salir al rail,
    // domingo al ir o volver de Suscripciones). Se compara con el día
    // actual, no con el widget anterior: ése puede haber quedado viejo.
    // Al saltar se usa el evento que ese día ya recordaba;
    // [initialEventIndex] sólo vale al armarse el panel.
    final day = widget.initialDayIndex.clamp(0, 6);
    if (day != _selectedDayIndex) {
      _selectedDayIndex = day;
      _focusSection = _FocusSection.grid;
      widget.onEventIndexChanged?.call(_selectedEventIndices[day] ?? 0);
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
    if (!widget.focusNode.hasFocus && _gridActionPressed) {
      _gridActionPressed = false;
    }
    _hadFocus = widget.focusNode.hasFocus;
  }

  /// `setState` para el `part` de teclas: las extensiones no pueden llamarlo
  /// directo porque es `@protected`.
  void _update(VoidCallback fn) => setState(fn);

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
                        MoaiIcons.calendarEvents,
                        size: MoaiIconSizes.md,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          MoaiFormats.weekRange(monday, sunday),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.display(
                            context,
                            fontSize: 15,
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
                    final isFocused =
                        isPanelFocused &&
                        _focusSection == _FocusSection.header &&
                        _headerActionIndex == idx;

                    switch (action) {
                      case _HeaderAction.refresh:
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TvWeekHeaderButton(
                            icon: MoaiIcons.refresh,
                            tooltip: LocaleKeys.calendar_refresh.tr(),
                            isFocused: isFocused,
                            isLoading: calendar.isLoading,
                            onTap: () {
                              _headerActionIndex = idx;
                              _refreshCalendar(calendar);
                              widget.focusNode.requestFocus();
                            },
                          ),
                        );
                      case _HeaderAction.prev:
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TvWeekHeaderButton(
                            icon: MoaiIcons.chevronLeft,
                            tooltip: LocaleKeys.calendar_week_nav_prev.tr(),
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
                          child: TvWeekHeaderButton(
                            icon: MoaiIcons.calendarToday,
                            label: LocaleKeys.calendar_week_current.tr(),
                            isFocused: isFocused,
                            onTap: () {
                              _headerActionIndex = idx;
                              _executeHeaderAction(action);
                              widget.focusNode.requestFocus();
                            },
                          ),
                        );
                      case _HeaderAction.next:
                        return TvWeekHeaderButton(
                          icon: MoaiIcons.chevronRight,
                          tooltip: LocaleKeys.calendar_week_nav_next.tr(),
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
                  final isDayColumnSelected =
                      isPanelFocused &&
                      _focusSection == _FocusSection.grid &&
                      _selectedDayIndex == dayIdx;

                  final currentEventIndex = (_selectedEventIndices[dayIdx] ?? 0)
                      .clamp(0, dayEvents.isEmpty ? 0 : dayEvents.length - 1);

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
                        actionPressed:
                            _gridActionPressed && isDayColumnSelected,
                        onSelectEvent: (eventIdx) {
                          setState(() {
                            _focusSection = _FocusSection.grid;
                            _selectedDayIndex = dayIdx;
                            _selectedEventIndices[dayIdx] = eventIdx;
                          });
                          widget.onDayChanged?.call(dayIdx);
                          widget.onEventIndexChanged?.call(eventIdx);
                          widget.focusNode.requestFocus();
                          if (eventIdx < dayEvents.length) {
                            final ev = dayEvents[eventIdx];
                            _showEventDetails(context, ev);
                          }
                        },
                        onSelectColumn: () {
                          setState(() {
                            _focusSection = _FocusSection.grid;
                            _selectedDayIndex = dayIdx;
                          });
                          widget.onDayChanged?.call(dayIdx);
                          widget.onEventIndexChanged?.call(
                            _selectedEventIndices[dayIdx] ?? 0,
                          );
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
