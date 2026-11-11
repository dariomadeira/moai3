import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';

/// Panel de Gestión de Suscripciones Deportivas en Moai TV.
/// Utiliza exactamente la misma métrica de lista y alineación inferior que ChannelListPanel (TvWindowedList),
/// combinada con los ítems nativos de ajustes TV (TvSettingsSwitchRow) en su tamaño real y sin estirar.
class CalendarSubscriptionsPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const CalendarSubscriptionsPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<CalendarSubscriptionsPanel> createState() =>
      CalendarSubscriptionsPanelState();
}

class CalendarSubscriptionsPanelState
    extends State<CalendarSubscriptionsPanel> {
  final _listKey = GlobalKey<TvWindowedListState<SportSubscription>>();
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  void didUpdateWidget(covariant CalendarSubscriptionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      _selectedIndex = widget.initialIndex;
    }
  }

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final subscriptions = calendar.subscriptions;

    if (subscriptions.isNotEmpty && _selectedIndex >= subscriptions.length) {
      _selectedIndex = subscriptions.length - 1;
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: TvPanelSlots.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: LocaleKeys.calendar_panel_subscriptions_title.tr(),
              subtitle: LocaleKeys.calendar_subscriptions_desc.tr(),
              // El degradado de la hora del Inicio, como el rango de fechas
              // de Eventos.
              titleShader: HomeClock.timeShader,
            ),
            TvPanelSlots.belowHeader,
            Expanded(
              child: subscriptions.isEmpty
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final itemExtent = TvPanelSlots.extentFor(
                          constraints.maxHeight,
                        );
                        return Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            height: (TvPanelSlots.count * itemExtent).clamp(
                              0.0,
                              constraints.maxHeight,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: TvWindowedList<SportSubscription>(
                                key: _listKey,
                                // La entrada de foco la decide el área (rail →, cambio de panel).
                                focusOnMount: false,
                                items: subscriptions,
                                itemExtent: itemExtent,
                                showScrollDots: true,
                                initialGlobalIndex: _selectedIndex,
                                onFocusedGlobalIndex: (idx) {
                                  _selectedIndex = idx;
                                  widget.onSelectedIndexChanged?.call(idx);
                                },
                                itemBuilder:
                                    (
                                      context,
                                      sub,
                                      focusNode,
                                      local,
                                      global,
                                      onKeyUp,
                                      onKeyDown,
                                    ) {
                                      // El color del deporte, el mismo de
                                      // sus eventos, encendido o no.
                                      final sportColor =
                                          CalendarProvider.getSubscriptionColor(
                                            sub.id,
                                            context.scheme.primary,
                                          );
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: TvPanelSlots.gap / 2,
                                        ),
                                        child: TvSettingsSwitchRow(
                                          focusNode: focusNode,
                                          icon: sub.icon,
                                          iconColor: sportColor,
                                          label: sub.name.tr(),
                                          description: sub.description?.tr(),
                                          value: sub.isSubscribed,
                                          onChanged: (_) => calendar
                                              .toggleSubscription(sub.id),
                                          onKeyLeft: widget.onKeyLeft,
                                          onKeyUp: onKeyUp,
                                          onKeyDown: onKeyDown,
                                        ),
                                      );
                                    },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
