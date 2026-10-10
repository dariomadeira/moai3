import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';

/// Pantalla para elegir el país de la agenda.
/// Misma métrica que [CalendarSubscriptionsPanel]: encabezado arriba y
/// ventana de 6 filas anclada abajo.
class AgendaUtcOffsetScreen extends StatefulWidget {
  const AgendaUtcOffsetScreen({super.key});

  @override
  State<AgendaUtcOffsetScreen> createState() => _AgendaUtcOffsetScreenState();
}

class _AgendaUtcOffsetScreenState extends State<AgendaUtcOffsetScreen> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey = GlobalKey<TvWindowedListState<AgendaTimeZone>>();
  final _backFocus = FocusNode(debugLabel: 'agenda_utc_back');
  late final int _initialIndex;

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final currentId = context.read<AgendaClockProvider>().zone.id;
    final index =
        AgendaClockProvider.zones.indexWhere((zone) => zone.id == currentId);
    _initialIndex = index < 0 ? 0 : index;
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Future<void> _select(AgendaTimeZone zone) async {
    await context.read<AgendaClockProvider>().setZone(zone.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final selectedId = context.watch<AgendaClockProvider>().zone.id;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TvPanelHeader(
                    title: 'settings_agenda_utc_title'.tr(),
                    subtitle: 'settings_agenda_utc_subtitle'.tr(),
                    backFocusNode: _backFocus,
                    onBack: _close,
                    onBackKeyDown: () =>
                        _listKey.currentState?.ensureVisible(_initialIndex),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final targetHeight = (_windowSize * _itemExtent)
                            .clamp(0.0, constraints.maxHeight);
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: targetHeight,
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: TvWindowedList<AgendaTimeZone>(
                                key: _listKey,
                                items: AgendaClockProvider.zones,
                                windowSize: _windowSize,
                                itemExtent: _itemExtent,
                                showScrollDots: true,
                                initialGlobalIndex: _initialIndex,
                                onFocusUpFromFirst: () =>
                                    _backFocus.requestFocus(),
                                itemBuilder: (
                                  context,
                                  zone,
                                  focusNode,
                                  local,
                                  global,
                                  onKeyUp,
                                  onKeyDown,
                                ) {
                                  final isSelected = zone.id == selectedId;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: TvTile(
                                      focusNode: focusNode,
                                      icon: AppIcons.globe,
                                      label: zone.nameKey.tr(),
                                      description: ArgentinaTime.formatOffset(
                                        zone.offsetHours,
                                      ),
                                      onPressed: () => _select(zone),
                                      onKeyLeft: _close,
                                      onKeyUp: onKeyUp,
                                      onKeyDown: onKeyDown,
                                      trailingBuilder: (context, isFocused) {
                                        if (!isSelected) {
                                          return const SizedBox(width: 26);
                                        }
                                        return AppIcon(
                                          icon: AppIcons.check,
                                          size: 26,
                                          color: isFocused
                                              ? scheme.onPrimary
                                              : scheme.primary,
                                        );
                                      },
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
          ),
      ),
    );
  }
}
