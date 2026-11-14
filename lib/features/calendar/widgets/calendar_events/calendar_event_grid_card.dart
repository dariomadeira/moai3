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

    // Ficha de cristal como las del Inicio: el foco es el borde del acento.
    // REDISEÑO: el ícono en el color del deporte; título y hora en el gris
    // oscuro de los subtítulos (no negro), el del modo. Terminado queda
    // apagado.
    final subtitleColor = MoaiPalette.of(context).inkSoft;
    final dimmed = isFinished && !isFocused;
    final fgColor = dimmed
        ? subtitleColor.withValues(alpha: 0.55)
        : subtitleColor;
    final sportColor = MoaiSportColors.of(event.subscriptionId, scheme.primary);
    final iconColor = dimmed ? sportColor.withValues(alpha: 0.55) : sportColor;

    // El tag "En vivo" del Inicio, con un color para FIN y otro para PRÓX.
    final Widget? chip;
    if (isFinished) {
      chip = MoaiStatusTag(
        label: LocaleKeys.calendar_status_finished.tr(),
        color: MoaiStatusTag.finishedColor,
      );
    } else if (isLive) {
      chip = MoaiStatusTag(
        label: LocaleKeys.calendar_status_live.tr(),
        color: MoaiStatusTag.liveColor,
      );
    } else if (isSoon) {
      chip = MoaiStatusTag(
        label: LocaleKeys.calendar_status_upcoming_short.tr(),
        color: MoaiStatusTag.soonColor,
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
                      Icon(sportIcon, size: MoaiIconSizes.md, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        event.formattedTime,
                        style: MoaiText.display(
                          context,
                          fontSize: MoaiText.sizeCaption,
                          color: fgColor,
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
                    fontSize: MoaiText.sizeDense,
                    fontWeight: FontWeight.w700,
                    color: fgColor,
                    height: 1.2,
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
