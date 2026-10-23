part of '../calendar_events_panel.dart';

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

  static const _dayNames = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  bool get _isToday {
    final now = ArgentinaTime.now();
    return now.year == day.year && now.month == day.month && now.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dayLabel = _dayNames[(day.weekday - 1).clamp(0, 6)];
    final isToday = _isToday;

    // Colores para el encabezado del día con gradiente y borde sutil
    final Color headerBase;
    final Color headerDayNameColor;
    final Color headerDayNumberColor;

    if (isToday) {
      if (isColumnFocused) {
        headerBase = scheme.primary;
        headerDayNameColor = scheme.onPrimary;
        headerDayNumberColor = scheme.onPrimary;
      } else {
        headerBase = scheme.primaryContainer;
        headerDayNameColor = scheme.primary;
        headerDayNumberColor = scheme.onPrimaryContainer;
      }
    } else {
      if (isColumnFocused) {
        headerBase = scheme.secondaryContainer;
        headerDayNameColor = scheme.onSecondaryContainer;
        headerDayNumberColor = scheme.onSecondaryContainer;
      } else {
        headerBase = scheme.surfaceContainer;
        headerDayNameColor = scheme.onSurfaceVariant;
        headerDayNumberColor = scheme.onSurface;
      }
    }

    final headerBorderColor = isColumnFocused
        ? (isToday
              ? scheme.onPrimary.withValues(alpha: 0.65)
              : scheme.secondary.withValues(alpha: 0.55))
        : (isToday
              ? scheme.primary.withValues(alpha: 0.40)
              : scheme.outlineVariant.withValues(alpha: 0.20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del día con borde a juego
        _PressScale(
          onTap: onSelectColumn,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: headerBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: headerBorderColor),
            ),
            child: Stack(
              children: [
                Column(
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
                if (events.isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Badge(
                      backgroundColor: scheme.tertiaryContainer,
                      textColor: scheme.onTertiaryContainer,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                      label: Text('${events.length}'),
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
    final start = windowStart.clamp(
      0,
      (events.length - windowSize).clamp(0, events.length),
    );
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
          final slotHeight =
              (totalHeight - ((windowSize - 1) * gap)) / windowSize;
          final safeSlotHeight = slotHeight.clamp(30.0, 150.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(count, (i) {
              final globalIndex = start + i;
              final event = visibleEvents[i];
              final isItemFocused =
                  isColumnFocused && selectedEventIndex == globalIndex;

              return Padding(
                padding: EdgeInsets.only(bottom: i < count - 1 ? gap : 0),
                child: _CalendarEventGridCard(
                  event: event,
                  isFocused: isItemFocused,
                  actionPressed: isItemFocused && actionPressed,
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
        final slotHeight =
            (availableHeight - ((windowSize - 1) * gap)) / windowSize;
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          MoaiIcons.keyboardArrowUp,
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
              final isItemFocused =
                  isColumnFocused && selectedEventIndex == globalIndex;

              return Padding(
                padding: EdgeInsets.only(bottom: i < count - 1 ? gap : 0),
                child: _CalendarEventGridCard(
                  event: event,
                  isFocused: isItemFocused,
                  actionPressed: isItemFocused && actionPressed,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          MoaiIcons.keyboardArrowDown,
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

    final baseColor = isFocused
        ? scheme.secondaryContainer
        : scheme.surfaceContainerLow;
    final borderColor = isFocused
        ? scheme.secondary.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.18);

    return _PressScale(
      onTap: onSelectColumn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MoaiIcons.eventBusyOutlined,
              size: 24,
              color: isFocused ? scheme.onSecondaryContainer : scheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.calendar_no_events_day.tr(),
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

/// Tarjeta de evento: ícono + hora + título. Paleta por estado (vencido / vivo / hoy / futuro).
