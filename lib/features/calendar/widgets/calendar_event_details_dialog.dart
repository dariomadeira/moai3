import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/tv_info_row.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/calendar/calendar_channel_matcher.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';

/// Diálogo de detalle de un evento de la Agenda con los canales que lo pasan.
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
        _listKey.currentState?.ensureVisible(0);
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

  /// Tag de estado del encabezado: el de las tarjetas de la Agenda
  /// ([MoaiStatusTag], grande), con más información: EN VIVO, FINALIZADO o,
  /// si falta, cuándo empieza (HOY · 12:30, MAÑANA, EN 3 DÍAS).
  Widget _statusTag() {
    final event = widget.event;
    if (widget.isLive) {
      return MoaiStatusTag(
        label: LocaleKeys.calendar_status_live_long.tr(),
        color: MoaiStatusTag.liveColor,
        large: true,
      );
    }
    if (event.status == CalendarEventStatus.finished) {
      return MoaiStatusTag(
        label: LocaleKeys.calendar_status_finished_long.tr(),
        color: MoaiStatusTag.finishedColor,
        large: true,
      );
    }
    final days = ArgentinaTime.dateOnly(
      event.startDateTime,
    ).difference(ArgentinaTime.dateOnly(ArgentinaTime.utcNow())).inDays;
    final time = {'time': event.formattedTime};
    final String label;
    if (days <= 0) {
      label = event.timeConfirmed
          ? LocaleKeys.calendar_status_today_at.tr(namedArgs: time)
          : LocaleKeys.calendar_status_today.tr();
    } else if (days == 1) {
      label = event.timeConfirmed
          ? LocaleKeys.calendar_status_tomorrow_at.tr(namedArgs: time)
          : LocaleKeys.calendar_status_tomorrow.tr();
    } else {
      label = LocaleKeys.calendar_status_in_days.tr(
        namedArgs: {'days': '$days'},
      );
    }
    return MoaiStatusTag(
      label: label,
      color: MoaiStatusTag.soonColor,
      large: true,
    );
  }

  /// Título chico de una columna ("Dónde verlo").
  Widget _sectionTitle(BuildContext context, ColorScheme scheme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: MoaiText.body(
          context,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final scheme = context.scheme;
    final hasChannels = _matchingChannels.isNotEmpty;

    // REDISEÑO (2026-11-04): los datos en UNA ficha de cristal, separados
    // por líneas finas (antes tres recuadros sueltos).
    final divider = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        thickness: 1,
        color: scheme.onSurface.withValues(alpha: 0.08),
      ),
    );
    final hasBroadcaster =
        event.broadcaster != null && event.broadcaster!.isNotEmpty;
    final detailsColumn = MoaiGlass(
      borderRadius: MoaiGlass.panelRadius,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvInfoRow(
            icon: MoaiIcons.calendarDialogTime,
            label: LocaleKeys.calendar_event_time.tr(),
            value: event.timeConfirmed
                ? LocaleKeys.calendar_event_date_time.tr(
                    namedArgs: {
                      'date': event.formattedDate,
                      'time': event.formattedTime,
                    },
                  )
                : LocaleKeys.calendar_event_date_time_tbd.tr(
                    namedArgs: {'date': event.formattedDate},
                  ),
          ),
          divider,
          TvInfoRow(
            icon: MoaiIcons.calendarDialogSport,
            label: LocaleKeys.calendar_event_sport.tr(),
            value: event.sessionType?.tr() ?? event.competition,
          ),
          if (hasBroadcaster) ...[
            divider,
            TvInfoRow(
              icon: MoaiIcons.calendarDialogBroadcast,
              label: LocaleKeys.calendar_event_broadcaster.tr(),
              value: event.broadcaster!,
            ),
          ],
        ],
      ),
    );

    final contentWidget = hasChannels
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna 1: Datos del evento
              Expanded(flex: 10, child: detailsColumn),
              const SizedBox(width: 20),
              // Columna 2: los canales que lo pasan, sueltos sobre el panel
              // (antes en un pozo gris que apagaba los ítems de cristal).
              Expanded(
                flex: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(
                      context,
                      scheme,
                      LocaleKeys.calendar_event_channels_title.tr(),
                    ),
                    TvWindowedList<Channel>(
                      key: _listKey,
                      items: _matchingChannels,
                      windowSize: 4,
                      showScrollDots: true,
                      itemBuilder:
                          (
                            context,
                            ch,
                            focusNode,
                            local,
                            global,
                            onKeyUp,
                            onKeyDown,
                          ) {
                            return NewChannelCard(
                              key: ValueKey(ch.id),
                              channel: ch,
                              isSelected: false,
                              focusNode: focusNode,
                              onKeyLeft: _closeFocusNode.requestFocus,
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
                  ],
                ),
              ),
            ],
          )
        : detailsColumn;

    return TvDialog(
      width: hasChannels ? 860 : 520,
      padding: const EdgeInsets.all(20),
      icon: MoaiIcons.calendarDialogTitle,
      title: event.title,
      subtitle: event.competition,
      trailingHeader: _statusTag(),
      content: contentWidget,
      actions: [
        Focus(
          onKeyEvent: (node, keyEvent) {
            if (keyEvent is KeyDownEvent && hasChannels) {
              if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight ||
                  keyEvent.logicalKey == LogicalKeyboardKey.arrowUp) {
                _listKey.currentState?.ensureVisible(0);
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: TvDialogButton(
            focusNode: _closeFocusNode,
            label: LocaleKeys.common_close.tr(),
            autofocus: !widget.isLive || !hasChannels,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

Future<void> showCalendarEventDetails(
  BuildContext context,
  CalendarEvent event, {
  ValueChanged<Channel>? onTuneChannel,
}) async {
  await showTvGeneralDialog<void>(
    context: context,
    barrierLabel: LocaleKeys.common_close.tr(),
    builder: (dialogContext) {
      return _CalendarEventDialogContent(
        event: event,
        isLive: event.status == CalendarEventStatus.live,
        onTuneChannel: onTuneChannel,
      );
    },
  );
}
