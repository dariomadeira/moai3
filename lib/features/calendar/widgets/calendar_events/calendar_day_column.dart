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

  bool get _isToday {
    final now = ArgentinaTime.now();
    return now.year == day.year && now.month == day.month && now.day == day.day;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dayLabel = MoaiFormats.weekdayShort(day.weekday);
    final isToday = _isToday;

    // Encabezado de cristal: hoy va teñido del acento y la columna con foco
    // lleva el borde del acento (mismo criterio que TvTile).
    final headerDayNameColor = isToday
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final headerDayNumberColor = scheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header del día con borde a juego
        _PressScale(
          onTap: onSelectColumn,
          child: MoaiGlass(
            borderRadius: 12,
            elevated: false,
            solid: true,
            focused: isColumnFocused,
            tint: isToday ? scheme.primary : null,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
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
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: moaiGlassChipDecoration(
                        scheme,
                        highlighted: isToday || isColumnFocused,
                      ),
                      child: Text(
                        '${events.length}',
                        textAlign: TextAlign.center,
                        style: MoaiText.body(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isToday || isColumnFocused
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
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
                        decoration: moaiGlassChipDecoration(
                          scheme,
                          highlighted: true,
                        ),
                        child: Icon(
                          MoaiIcons.chevronUp,
                          size: MoaiIconSizes.xs,
                          color: scheme.primary,
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
                        decoration: moaiGlassChipDecoration(
                          scheme,
                          highlighted: true,
                        ),
                        child: Icon(
                          MoaiIcons.chevronDown,
                          size: MoaiIconSizes.xs,
                          color: scheme.primary,
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

    final dark = scheme.brightness == Brightness.dark;
    final line = dark ? Colors.white : scheme.onSurface;
    final contentColor = isFocused
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return _PressScale(
      onTap: onSelectColumn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        // Pozo de cristal; con foco, el borde del acento se pinta encima
        // (no ocupa espacio) y el relleno toma un tinte suave.
        decoration: BoxDecoration(
          color: isFocused
              ? scheme.primary.withValues(alpha: dark ? 0.08 : 0.06)
              : line.withValues(alpha: dark ? 0.03 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line.withValues(alpha: 0.08)),
        ),
        foregroundDecoration: isFocused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MoaiIcons.calendarEmptyDay,
              size: MoaiIconSizes.lg,
              color: isFocused ? scheme.primary : contentColor,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.calendar_no_events_day.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: isFocused ? FontWeight.w700 : FontWeight.w500,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de evento: ícono + hora + título. Paleta por estado (vencido / vivo / hoy / futuro).
