import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';

/// Widget de eventos del Inicio, en franja como [HomeWeatherCard]: a la
/// izquierda el resumen del día y a la derecha los eventos de hoy de las
/// suscripciones que están en curso o por empezar, en fila. Sin eventos el
/// Inicio no la muestra.
///
/// El foco y la selección los maneja el Inicio: [selectedIndex] es el
/// evento elegido (←/→ lo mueven, OK abre el detalle).
class HomeEventsCard extends StatelessWidget {
  const HomeEventsCard({
    super.key,
    required this.events,
    required this.selectedIndex,
    this.isFocused = false,
  });

  final List<CalendarEvent> events;
  final int selectedIndex;
  final bool isFocused;

  static const double radius = 16;

  /// REDISEÑO: el color de la tarjeta (su ícono) y del tag "En vivo".
  static const Color liveColor = MoaiStatusTag.liveColor;
  static const double _tileWidth = 236;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    final count = events.length;

    // REDISEÑO: el cristal de las tarjetas del Inicio, sin halo de color
    // (como el clima). El foco lo lleva el evento elegido, no la tarjeta.
    return MoaiGlass(
      borderRadius: radius,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: HomeCardSummary.width,
            child: HomeCardSummary(
              label: LocaleKeys.calendar_panel_events_title.tr(),
              icon: MoaiIcons.calendarEvents,
              color: liveColor,
              title: LocaleKeys.home_events_today.tr(),
              line: count == 1
                  ? LocaleKeys.home_events_count_one.tr()
                  : LocaleKeys.home_events_count.tr(
                      namedArgs: {'count': '$count'},
                    ),
            ),
          ),
          const HomeCardDivider(),
          Expanded(
            child: _EventStrip(
              events: events,
              selectedIndex: selectedIndex,
              isFocused: isFocused,
            ),
          ),
        ],
      ),
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
        final tilesWidth = constraints.maxWidth - 2 * HomeEdgePill.width;
        final visible = ((tilesWidth + HomeEventsCard._tileGap) ~/ step).clamp(
          1,
          events.length,
        );
        final selected = selectedIndex.clamp(0, events.length - 1);
        return HomeRowWindow(
          count: events.length,
          visible: visible,
          selected: selected,
          builder: (start) => Row(
            children: [
              HomeEdgePill(icon: MoaiIcons.dpadLeft, active: start > 0),
              Expanded(
                child: Row(
                  // La primera arranca siempre donde arrancaría con la fila llena
                  // (centrada entre las flechas), aunque haya menos.
                  children: [
                    SizedBox(
                      width: HomeRowWindow.inset(
                        width: tilesWidth,
                        tileWidth: HomeEventsCard._tileWidth,
                        gap: HomeEventsCard._tileGap,
                      ),
                    ),
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
              HomeEdgePill(
                icon: MoaiIcons.dpadRight,
                active: start + visible < events.length,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un evento: deporte, hora y estado arriba; título y competencia abajo.
/// En vivo sólo lleva el tag, sin teñir la tarjeta (acá sólo llegan eventos
/// en curso o próximos).
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
    const live = HomeEventsCard.liveColor;
    final String? chip = isLive ? LocaleKeys.calendar_status_live.tr() : null;

    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
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
                // REDISEÑO: el color del deporte, como en la Agenda.
                color: CalendarProvider.getSubscriptionColor(
                  event.subscriptionId,
                  accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.formattedTime,
                style: MoaiText.body(
                  context,
                  // REDISEÑO: gris suave, no el acento.
                  color: scheme.onSurfaceVariant,
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
                // REDISEÑO: chico, del tamaño del tag de la tarjeta grande
                // de eventos, con el degradé de un botón con foco en el color
                // de la tarjeta y un brillo suave.
                MoaiStatusTag(label: chip, color: live),
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
