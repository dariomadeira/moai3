import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/state/agenda_clock_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
/// Diálogo modal interactivo para Android TV que permite buscar y seleccionar
/// la zona horaria (país / desfase UTC) de la agenda.
class TvAgendaTimeZoneDialog extends StatefulWidget {
  const TvAgendaTimeZoneDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showTvGeneralDialog(
      context: context,
      barrierLabel: 'TvAgendaTimeZoneDialog',
      builder: (_) => const TvAgendaTimeZoneDialog(),
    );
  }

  @override
  State<TvAgendaTimeZoneDialog> createState() => _TvAgendaTimeZoneDialogState();
}

class _TvAgendaTimeZoneDialogState extends State<TvAgendaTimeZoneDialog> {
  final FocusNode _searchFocusNode =
      FocusNode(debugLabel: 'agenda_tz_search_focus');
  final FocusNode _closeBtnFocus =
      FocusNode(debugLabel: 'agenda_tz_close_btn_focus');
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<TvWindowedListState<AgendaTimeZone>> _listKey =
      GlobalKey<TvWindowedListState<AgendaTimeZone>>();

  List<AgendaTimeZone> _filteredZones = [];
  int _selectedResultIndex = 0;

  @override
  void initState() {
    super.initState();
    _filteredZones = List.of(AgendaClockProvider.zones);

    final currentId = context.read<AgendaClockProvider>().zone.id;
    final initialIdx =
        _filteredZones.indexWhere((zone) => zone.id == currentId);
    _selectedResultIndex = initialIdx < 0 ? 0 : initialIdx;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _closeBtnFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim().toLowerCase();
    setState(() {
      if (trimmed.isEmpty) {
        _filteredZones = List.of(AgendaClockProvider.zones);
      } else {
        _filteredZones = AgendaClockProvider.zones.where((zone) {
          final countryName = zone.nameKey.tr().toLowerCase();
          final offsetStr =
              ArgentinaTime.formatOffset(zone.offsetHours).toLowerCase();
          final rawOffset = '${zone.offsetHours}';
          return countryName.contains(trimmed) ||
              offsetStr.contains(trimmed) ||
              rawOffset.contains(trimmed);
        }).toList();
      }
      _selectedResultIndex = 0;
    });
  }

  Future<void> _selectZone(AgendaTimeZone zone) async {
    await context.read<AgendaClockProvider>().setZone(zone.id);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final selectedId = context.watch<AgendaClockProvider>().zone.id;

    return TvDialog(
      width: 500,
      icon: MoaiIcons.publicOutlined,
      title: LocaleKeys.settings_agenda_utc_title.tr(),
      subtitle: LocaleKeys.settings_agenda_utc_subtitle.tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Buscador superior con teclado TV integrado
          TvTextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            label: LocaleKeys.settings_agenda_utc_search_hint.tr(),
            hint: LocaleKeys.search_field_hint.tr(),
            textInputAction: TvTextInputAction.search,
            dense: true,
            leadingIcon: MoaiIcons.searchOutlined,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _onSearchChanged(val);
              if (_filteredZones.isNotEmpty) {
                _listKey.currentState?.ensureVisible(0);
              }
            },
            onFocusDown: () {
              if (_filteredZones.isNotEmpty) {
                _listKey.currentState?.ensureVisible(0);
              } else {
                _closeBtnFocus.requestFocus();
              }
            },
          ),
          const SizedBox(height: 14),
          _buildListArea(context, scheme, selectedId),
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _closeBtnFocus,
          label: LocaleKeys.common_close.tr(),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          onKeyUp: () {
            if (_filteredZones.isNotEmpty) {
              _listKey.currentState
                  ?.ensureVisible(_filteredZones.length - 1);
            } else {
              _searchFocusNode.requestFocus();
            }
          },
        ),
      ],
    );
  }

  Widget _buildListArea(
    BuildContext context,
    ColorScheme scheme,
    String selectedId,
  ) {
    if (_filteredZones.isEmpty) {
      return Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.locationOffOutlined,
              size: 28,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.settings_agenda_utc_no_results.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    const windowSize = 3;
    const itemExtent = 66.0;
    const targetHeight = (windowSize * itemExtent);

    return SizedBox(
      height: targetHeight,
      child: TvWindowedList<AgendaTimeZone>(
        key: _listKey,
        items: _filteredZones,
        windowSize: windowSize,
        itemExtent: itemExtent,
        showScrollDots: true,
        initialGlobalIndex: _selectedResultIndex,
        onFocusUpFromFirst: _searchFocusNode.requestFocus,
        onFocusDownFromLast: _closeBtnFocus.requestFocus,
        onFocusedGlobalIndex: (idx) => _selectedResultIndex = idx,
        itemBuilder: (
          context,
          zone,
          focusNode,
          localIndex,
          globalIndex,
          onKeyUp,
          onKeyDown,
        ) {
          final isSelected = zone.id == selectedId;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: TvTile(
              focusNode: focusNode,
              minHeight: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              label: zone.nameKey.tr(),
              description: ArgentinaTime.formatOffset(zone.offsetHours),
              icon: MoaiIcons.publicOutlined,
              onPressed: () => _selectZone(zone),
              onKeyUp: onKeyUp,
              onKeyDown: onKeyDown,
              trailingBuilder: (context, isFocused) {
                if (!isSelected) {
                  return const SizedBox(width: 22);
                }
                return Icon(
                  MoaiIcons.checkOutlined,
                  size: 20,
                  color: isFocused ? scheme.onPrimary : scheme.primary,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
