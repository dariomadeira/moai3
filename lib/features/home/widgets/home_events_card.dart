import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Widget de eventos del Inicio, en franja como [HomeWeatherCard]: a la
/// izquierda el resumen del día y a la derecha los eventos de hoy de las
/// suscripciones que están en curso o por empezar, en fila. Sin eventos
/// muestra un aviso y el botón para ir a Suscripciones.
///
/// El foco y la selección los maneja el Inicio: con eventos, [selectedIndex]
/// es el evento elegido (←/→ lo mueven, OK abre el detalle); sin eventos el
/// foco es de la tarjeta.
class HomeEventsCard extends StatelessWidget {
  const HomeEventsCard({
    super.key,
    required this.events,
    required this.selectedIndex,
    required this.hasSubscriptions,
    this.isFocused = false,
  });

  final List<CalendarEvent> events;
  final int selectedIndex;

  /// Sin eventos: si hay alguna suscripción sólo se avisa que no hay nada
  /// para mostrar; si no hay ninguna, se ofrece el botón a Suscripciones.
  final bool hasSubscriptions;
  final bool isFocused;

  static const double radius = 16;
  static const double _tileWidth = 236;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hasEvents = events.isNotEmpty;

    return HomeCard(
      glow: HomeCardColors.events,
      // Con eventos el foco lo lleva el evento elegido, no la tarjeta.
      focused: isFocused && !hasEvents,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(width: 214, child: _Summary(count: events.length)),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 16),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: hasEvents
                ? _EventStrip(
                    events: events,
                    selectedIndex: selectedIndex,
                    isFocused: isFocused,
                  )
                : hasSubscriptions
                ? const _NothingToShow()
                : _Empty(isFocused: isFocused),
          ),
        ],
      ),
    );
  }
}

/// "Eventos" + "Hoy" en grande + cuántos hay.
class _Summary extends StatelessWidget {
  const _Summary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;
    final countLabel = count == 1
        ? LocaleKeys.home_events_count_one.tr()
        : LocaleKeys.home_events_count.tr(namedArgs: {'count': '$count'});

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.calendar_panel_events_title.tr(),
          style: MoaiText.body(
            context,
            color: muted,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        Row(
          children: [
            Icon(
              MoaiIcons.calendarEvents,
              size: MoaiIconSizes.xl,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                LocaleKeys.home_events_today.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        Text(
          countLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Fila de eventos con ventana: muestra los que entran y se corre para que
/// el elegido siempre se vea. Las flechas de los costados avisan que hay
/// más eventos de ese lado (se encienden con el acento).
class _EventStrip extends StatelessWidget {
  const _EventStrip({
    required this.events,
    required this.selectedIndex,
    required this.isFocused,
  });

  final List<CalendarEvent> events;
  final int selectedIndex;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const step = HomeEventsCard._tileWidth + HomeEventsCard._tileGap;
        // Las flechas ocupan su lugar siempre, así la fila no salta.
        final tilesWidth = constraints.maxWidth - 2 * _Edge.width;
        final visible = ((tilesWidth + HomeEventsCard._tileGap) ~/ step).clamp(
          1,
          events.length,
        );
        final selected = selectedIndex.clamp(0, events.length - 1);
        final start = (selected - visible + 1).clamp(
          0,
          events.length - visible,
        );

        return Row(
          children: [
            _Edge(icon: MoaiIcons.dpadLeft, active: start > 0),
            Expanded(
              child: Row(
                children: [
                  for (var i = start; i < start + visible; i++) ...[
                    if (i > start)
                      const SizedBox(width: HomeEventsCard._tileGap),
                    SizedBox(
                      width: HomeEventsCard._tileWidth,
                      child: _EventTile(
                        event: events[i],
                        isFocused: isFocused && i == selected,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Edge(
              icon: MoaiIcons.dpadRight,
              active: start + visible < events.length,
            ),
          ],
        );
      },
    );
  }
}

/// Flecha de un costado de la fila: con acento si hay eventos de ese lado,
/// casi invisible si no.
class _Edge extends StatelessWidget {
  const _Edge({required this.icon, required this.active});

  static const double width = 28;

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: width,
      child: Icon(
        icon,
        size: MoaiIconSizes.lg,
        color: active
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Un evento: deporte, hora y estado arriba; título y competencia abajo.
/// En vivo va teñido del acento, como en la grilla de la Agenda (acá sólo
/// llegan eventos en curso o próximos).
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.isFocused});

  final CalendarEvent event;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = event.status == CalendarEventStatus.live;
    final fg = scheme.onSurface;
    final accent = scheme.primary;
    final String? chip = isLive ? LocaleKeys.calendar_status_live.tr() : null;

    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
      tint: isLive ? scheme.primary : null,
      focused: isFocused,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CalendarProvider.getSubscriptionIcon(event.subscriptionId),
                size: MoaiIconSizes.md,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                event.formattedTime,
                style: MoaiText.body(
                  context,
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              // La competición va junto a la hora: con 4 tarjetas en el
              // Inicio no entra como tercera línea debajo del título.
              Expanded(
                child: event.competition.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(left: 6, right: 6),
                        child: Text(
                          '· ${event.competition}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: moaiGlassChipDecoration(
                    scheme,
                    highlighted: isLive,
                  ),
                  child: Text(
                    chip,
                    style: MoaiText.body(
                      context,
                      color: fg,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: fg,
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hay suscripciones pero nada en curso ni por empezar hoy.
class _NothingToShow extends StatelessWidget {
  const _NothingToShow();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        LocaleKeys.home_events_empty.tr(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MoaiText.body(
          context,
          color: context.scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Sin suscripciones: aviso y botón a Suscripciones (OK sobre la tarjeta).
class _Empty extends StatelessWidget {
  const _Empty({required this.isFocused});

  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            LocaleKeys.home_events_empty_desc.tr(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: scheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: moaiGlassButtonDecoration(scheme, focused: isFocused),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MoaiIcons.calendarSubscriptions,
                size: MoaiIconSizes.md,
                color: isFocused ? scheme.onPrimary : scheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.home_events_subscribe.tr(),
                style: MoaiText.body(
                  context,
                  color: isFocused ? scheme.onPrimary : scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
