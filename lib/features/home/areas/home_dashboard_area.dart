import 'dart:async';

import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/home_weather_card.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';

/// Área de Inicio (Dashboard).
/// Panel único a ancho completo con estilo de acordeón TV.
class HomeDashboardArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  const HomeDashboardArea({super.key, required this.onExitLeft});

  @override
  State<HomeDashboardArea> createState() => HomeDashboardAreaState();
}

class HomeDashboardAreaState extends HomeAreaState<HomeDashboardArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final FocusNode _panelFocusNode = FocusNode(
    debugLabel: 'home_dashboard_panel',
  );
  final _listKey = GlobalKey<TvWindowedListState<_HomeWidget>>();
  int _selectedIndex = 0;
  Timer? _hourTimer;
  DateTime _now = DateTime.now();

  /// Cada widget ocupa el doble que un ítem de Ajustes (70): 132 de card + 8.
  static const double _itemExtent = 140;
  static const int _windowSize = 3;

  @override
  void initState() {
    super.initState();
    _scheduleNextHour();
  }

  /// Refresca saludo y próximas horas del clima al cambiar la hora.
  void _scheduleNextHour() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _hourTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextHour();
    });
  }

  /// Saludo según la hora: mañana 6–12, tarde 12–20, noche 20–6.
  static String greetingKey(DateTime time) {
    final h = time.hour;
    if (h >= 6 && h < 12) return LocaleKeys.home_greeting_morning;
    if (h >= 12 && h < 20) return LocaleKeys.home_greeting_afternoon;
    return LocaleKeys.home_greeting_night;
  }

  @override
  void requestEntryFocus() {
    if (!mounted) return;
    _focus.node(_panelFocusNode);
  }

  @override
  void dispose() {
    _hourTimer?.cancel();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface.withValues(alpha: 0.8)],
      titles: [LocaleKeys.home_panel_home_title.tr()],
      icons: const [MoaiIcons.tvAccordionHome],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        return Focus(
          focusNode: _panelFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.onExitLeft();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onFocusChange: (hasFocus) {
            if (hasFocus) _listKey.currentState?.ensureVisible(_selectedIndex);
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
                TvPanelHeader(title: greetingKey(_now).tr(), subtitle: ''),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final targetHeight = (_windowSize * _itemExtent).clamp(
                        0.0,
                        constraints.maxHeight,
                      );
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          height: targetHeight,
                          child: TvWindowedList<_HomeWidget>(
                            key: _listKey,
                            // La entrada de foco la decide el área (rail →).
                            focusOnMount: false,
                            items: _HomeWidget.values,
                            windowSize: _windowSize,
                            itemExtent: _itemExtent,
                            showScrollDots: true,
                            initialGlobalIndex: _selectedIndex,
                            onFocusedGlobalIndex: (idx) => _selectedIndex = idx,
                            itemBuilder:
                                (
                                  context,
                                  item,
                                  focusNode,
                                  local,
                                  global,
                                  onKeyUp,
                                  onKeyDown,
                                ) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: _HomeWidgetItem(
                                    focusNode: focusNode,
                                    onKeyLeft: widget.onExitLeft,
                                    onKeyUp: onKeyUp,
                                    onKeyDown: onKeyDown,
                                    builder: (isFocused) =>
                                        _buildWidget(item, isFocused),
                                  ),
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
      },
    );
  }

  Widget _buildWidget(_HomeWidget item, bool isFocused) {
    switch (item) {
      case _HomeWidget.weather:
        final weather = context.watch<WeatherProvider?>()?.weather;
        if (weather == null) {
          return const MoaiGlass(
            borderRadius: HomeWeatherCard.radius,
            elevated: false,
            child: SizedBox.expand(),
          );
        }
        return HomeWeatherCard(
          weather: weather,
          now: _now,
          isFocused: isFocused,
        );
    }
  }
}

/// Widgets de información del Inicio, en el orden de la lista.
enum _HomeWidget { weather }

/// Ítem enfocable de la lista del Inicio: maneja las flechas y avisa al
/// [builder] si tiene el foco.
class _HomeWidgetItem extends StatefulWidget {
  const _HomeWidgetItem({
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.builder,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final Widget Function(bool isFocused) builder;

  @override
  State<_HomeWidgetItem> createState() => _HomeWidgetItemState();
}

class _HomeWidgetItemState extends State<_HomeWidgetItem> {
  late bool _isFocused = widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        return TvKeyHandler.handleDirectional(
          key: event.logicalKey,
          onLeft: widget.onKeyLeft,
          onUp: widget.onKeyUp,
          onDown: widget.onKeyDown,
        );
      },
      child: widget.builder(_isFocused),
    );
  }
}
