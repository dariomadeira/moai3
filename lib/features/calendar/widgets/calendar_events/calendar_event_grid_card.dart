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
    final isSoon = event.status == CalendarEventStatus.upcoming && event.isToday;
    final sportIcon = CalendarProvider.getSubscriptionIcon(
      event.subscriptionId,
    );

    final finishedLabel = LocaleKeys.calendar_status_finished.tr();

    // Paleta de colores adaptativa según estado y foco con gradiente y borde sutil
    final Color baseColor;
    final Color fgColor;
    final Color subColor;

    if (isFinished) {
      baseColor = isFocused
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerLowest;
      fgColor = isFocused ? scheme.onSurface : scheme.outline;
      subColor = scheme.outline;
    } else if (isFocused) {
      baseColor = scheme.primary;
      fgColor = scheme.onPrimary;
      subColor = scheme.onPrimary;
    } else if (isLive) {
      baseColor = scheme.surfaceContainerHighest;
      fgColor = scheme.onSurface;
      subColor = scheme.onSurfaceVariant;
    } else if (isSoon) {
      baseColor = scheme.surfaceContainerHigh;
      fgColor = scheme.onSurface;
      subColor = scheme.onSurfaceVariant;
    } else {
      baseColor = scheme.surfaceContainer;
      fgColor = scheme.onSurface;
      subColor = scheme.onSurfaceVariant;
    }

    final Color borderColor;
    if (isFocused) {
      borderColor = isFinished
          ? scheme.onSurface.withValues(alpha: 0.40)
          : scheme.onPrimary.withValues(alpha: 0.60);
    } else if (isLive) {
      borderColor = scheme.primary.withValues(alpha: 0.40);
    } else if (isFinished) {
      borderColor = scheme.outlineVariant.withValues(alpha: 0.16);
    } else if (isSoon) {
      borderColor = scheme.outlineVariant.withValues(alpha: 0.20);
    } else {
      borderColor = scheme.outlineVariant.withValues(alpha: 0.14);
    }

    return SizedBox(
      height: height,
      child: _PressScale(
        pressed: actionPressed,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
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
                          color: fgColor,
                        ),
                      ),
                      if (isFinished) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? scheme.onSurface.withValues(alpha: 0.18)
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            finishedLabel,
                            style: MoaiText.body(
                              context,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isFocused
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                              letterSpacing: 0.4,
                            ),
                          ),
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
                            LocaleKeys.calendar_status_live.tr(),
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
                      ] else if (isSoon) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? scheme.onPrimary.withValues(alpha: 0.2)
                                : scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            LocaleKeys.calendar_status_upcoming_short.tr(),
                            style: MoaiText.body(
                              context,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isFocused
                                  ? scheme.onPrimary
                                  : scheme.primary,
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
