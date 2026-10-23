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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final scheme = context.scheme;
    final hasChannels = _matchingChannels.isNotEmpty;
    final panelBase = scheme.surface.withValues(alpha: 0.8);
    final panelBorder = scheme.outlineVariant.withValues(alpha: 0.48);

    final detailsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TvInfoTile(
          icon: MoaiIcons.calendarDialogTime,
          label: LocaleKeys.calendar_event_time.tr(),
          description: '${event.formattedDate} • ${event.formattedTime} hs',
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
                  decoration: BoxDecoration(
                    color: panelBase,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: panelBorder,
                    ),
                  ),
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
      trailingHeader: widget.isLive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                LocaleKeys.calendar_status_live.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                  letterSpacing: 0.4,
                ),
              ),
            )
          : (widget.event.status == CalendarEventStatus.finished
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      LocaleKeys.calendar_status_finished.tr(),
                      style: MoaiText.body(
                        context,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      LocaleKeys.calendar_status_upcoming_short.tr(),
                      style: MoaiText.body(
                        context,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  )),
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
