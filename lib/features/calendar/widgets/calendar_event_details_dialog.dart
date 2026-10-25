import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/calendar/calendar_channel_matcher.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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

  /// Chip de estado del encabezado: EN VIVO pleno del acento, PRONTO
  /// resaltado y FIN neutro (mismo criterio que la tarjeta de la grilla).
  Widget _statusChip(BuildContext context, ColorScheme scheme) {
    final isFinished = widget.event.status == CalendarEventStatus.finished;
    final BoxDecoration decoration;
    final Color color;
    final String label;
    if (widget.isLive) {
      label = LocaleKeys.calendar_status_live.tr();
      color = scheme.onPrimary;
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.transparent),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.primary, Colors.white, 0.18)!,
            scheme.primary,
          ],
        ),
      );
    } else if (isFinished) {
      label = LocaleKeys.calendar_status_finished.tr();
      color = scheme.onSurfaceVariant;
      decoration = moaiGlassChipDecoration(scheme, radius: 6);
    } else {
      label = LocaleKeys.calendar_status_upcoming_short.tr();
      color = scheme.primary;
      decoration = moaiGlassChipDecoration(
        scheme,
        radius: 6,
        highlighted: true,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isLive) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final scheme = context.scheme;
    final hasChannels = _matchingChannels.isNotEmpty;

    final detailsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvInfoTile(
          icon: MoaiIcons.calendarDialogTime,
          label: LocaleKeys.calendar_event_time.tr(),
          description: LocaleKeys.calendar_event_date_time.tr(
            namedArgs: {
              'date': event.formattedDate,
              'time': event.formattedTime,
            },
          ),
        ),
        const SizedBox(height: 8),
        TvInfoTile(
          icon: MoaiIcons.calendarDialogSport,
          label: LocaleKeys.calendar_event_sport.tr(),
          description: event.sessionType?.tr() ?? event.competition,
        ),
        if (event.broadcaster != null && event.broadcaster!.isNotEmpty) ...[
          const SizedBox(height: 8),
          TvInfoTile(
            icon: MoaiIcons.calendarDialogBroadcast,
            label: LocaleKeys.calendar_event_broadcaster.tr(),
            description: event.broadcaster!,
          ),
        ],
      ],
    );

    final contentWidget = hasChannels
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna 1: Datos del evento
              Expanded(flex: 10, child: detailsColumn),
              const SizedBox(width: 20),
              // Columna 2: Panel contenedor con borde redondeado y lista oficial de canales
              Expanded(
                flex: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: moaiGlassWellDecoration(scheme),
                  child: TvWindowedList<Channel>(
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
                ),
              ),
            ],
          )
        : detailsColumn;

    return TvDialog(
      width: hasChannels ? 800 : 480,
      icon: MoaiIcons.calendarDialogTitle,
      title: event.title,
      subtitle: event.competition,
      trailingHeader: _statusChip(context, scheme),
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
