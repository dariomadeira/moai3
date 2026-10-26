part of '../calendar_events_panel.dart';

class _CalendarEventGridCard extends StatelessWidget {
  final CalendarEvent event;
  final bool isFocused;
  final bool actionPressed;
  final double height;
  final VoidCallback onTap;

  const _CalendarEventGridCard({
    required this.event,
    required this.isFocused,
    required this.actionPressed,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = event.status == CalendarEventStatus.live;
    final isFinished = event.status == CalendarEventStatus.finished;
    final isSoon =
        event.status == CalendarEventStatus.upcoming && event.isToday;
    final sportIcon = CalendarProvider.getSubscriptionIcon(
      event.subscriptionId,
    );

    // Ficha de cristal como TvTile: el foco es el borde del acento y el texto
    // no se invierte. El estado se lee por el chip y la intensidad del texto:
    // en vivo va teñido del acento, terminado queda apagado.
    final Color fgColor;
    final Color iconColor;
    if (isFinished && !isFocused) {
      fgColor = scheme.onSurfaceVariant.withValues(alpha: 0.6);
      iconColor = fgColor;
    } else {
      fgColor = scheme.onSurface;
      iconColor = isFinished
          ? scheme.onSurfaceVariant
          : scheme.primary.withValues(alpha: isFocused ? 1 : 0.75);
    }
    final timeColor = isSoon || isLive ? scheme.primary : fgColor;

    final Widget? chip;
    if (isFinished) {
      chip = TvWeekStatusChip(label: LocaleKeys.calendar_status_finished.tr());
    } else if (isLive) {
      chip = TvWeekStatusChip(
        label: LocaleKeys.calendar_status_live.tr(),
        style: TvWeekChipStyle.live,
      );
    } else if (isSoon) {
      chip = TvWeekStatusChip(
        label: LocaleKeys.calendar_status_upcoming_short.tr(),
        style: TvWeekChipStyle.highlighted,
      );
    } else {
      chip = null;
    }

    return SizedBox(
      height: height,
      child: _PressScale(
        pressed: actionPressed,
        onTap: onTap,
        child: MoaiGlass(
          borderRadius: 12,
          elevated: false,
          solid: true,
          focused: isFocused,
          tint: isLive ? scheme.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: ícono del deporte + hora + chip de estado.
              // FittedBox: no desborda en ningún ancho ni transición.
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(sportIcon, size: MoaiIconSizes.xs, color: iconColor),
                      const SizedBox(width: 4),
                      Text(
                        event.formattedTime,
                        style: MoaiText.display(
                          context,
                          fontSize: 10.5,
                          color: timeColor,
                        ),
                      ),
                      if (chip != null) ...[const SizedBox(width: 5), chip],
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
