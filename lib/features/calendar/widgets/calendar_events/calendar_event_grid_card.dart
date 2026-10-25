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
      chip = _StatusChip(label: LocaleKeys.calendar_status_finished.tr());
    } else if (isLive) {
      chip = _StatusChip(
        label: LocaleKeys.calendar_status_live.tr(),
        style: _StatusChipStyle.live,
      );
    } else if (isSoon) {
      chip = _StatusChip(
        label: LocaleKeys.calendar_status_upcoming_short.tr(),
        style: _StatusChipStyle.highlighted,
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

enum _StatusChipStyle { neutral, highlighted, live }

/// Micro-etiqueta de estado de la tarjeta (FIN / PRONTO / EN VIVO).
class _StatusChip extends StatelessWidget {
  final String label;
  final _StatusChipStyle style;

  const _StatusChip({
    required this.label,
    this.style = _StatusChipStyle.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = style == _StatusChipStyle.live;

    final decoration = switch (style) {
      _StatusChipStyle.neutral => moaiGlassChipDecoration(scheme, radius: 5),
      _StatusChipStyle.highlighted => moaiGlassChipDecoration(
        scheme,
        radius: 5,
        highlighted: true,
      ),
      // En vivo: pleno del acento, lo único sólido de la grilla.
      _StatusChipStyle.live => BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.transparent),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.primary, Colors.white, 0.18)!,
            scheme.primary,
          ],
        ),
      ),
    };

    final color = switch (style) {
      _StatusChipStyle.neutral => scheme.onSurfaceVariant,
      _StatusChipStyle.highlighted => scheme.primary,
      _StatusChipStyle.live => scheme.onPrimary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
