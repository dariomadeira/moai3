import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Panel de Gestión de Suscripciones Deportivas en Moai TV.
/// Utiliza exactamente la misma métrica de lista y alineación inferior que ChannelListPanel (TvWindowedList),
/// combinada con los ítems nativos de ajustes TV (TvSettingsSwitchRow) en su tamaño real y sin estirar.
class CalendarSubscriptionsPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;

  const CalendarSubscriptionsPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
  });

  @override
  State<CalendarSubscriptionsPanel> createState() =>
      CalendarSubscriptionsPanelState();
}

class CalendarSubscriptionsPanelState
    extends State<CalendarSubscriptionsPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 74.0; // 66px card + 8px gap vertical

  final _listKey = GlobalKey<TvWindowedListState<SportSubscription>>();
  int _selectedIndex = 0;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final calendar = context.watch<CalendarProvider>();
    final subscriptions = calendar.subscriptions;

    if (subscriptions.isNotEmpty && _selectedIndex >= subscriptions.length) {
      _selectedIndex = subscriptions.length - 1;
    }

    final listAlign = subscriptions.length < _windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

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
        padding: const EdgeInsets.only(
          left: 4,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'calendar_panel_subscriptions_title'.tr(),
                    style: MoaiText.display(
                      context,
                      color: scheme.onSurface,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'calendar_subscriptions_desc'.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: subscriptions.isEmpty
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: listAlign,
                      child: TvWindowedList<SportSubscription>(
                        key: _listKey,
                        items: subscriptions,
                        windowSize: _windowSize,
                        itemExtent: _itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedIndex,
                        onFocusedGlobalIndex: (idx) {
                          _selectedIndex = idx;
                        },
                        itemBuilder: (
                          context,
                          sub,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: TvSettingsSwitchRow(
                              focusNode: focusNode,
                              icon: sub.icon,
                              label: sub.name,
                              description: sub.description,
                              value: sub.isSubscribed,
                              onChanged: (_) =>
                                  calendar.toggleSubscription(sub.id),
                              onKeyLeft: widget.onKeyLeft,
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
