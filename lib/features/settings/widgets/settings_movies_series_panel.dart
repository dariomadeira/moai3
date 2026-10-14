import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_catalog_frequency_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

enum _SettingsMoviesSeriesItemType {
  skipCatalog,
  catalogFrequency,
}

class SettingsMoviesSeriesPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsMoviesSeriesPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsMoviesSeriesPanel> createState() =>
      SettingsMoviesSeriesPanelState();
}

class SettingsMoviesSeriesPanelState extends State<SettingsMoviesSeriesPanel> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

  final _listKey =
      GlobalKey<TvWindowedListState<_SettingsMoviesSeriesItemType>>();
  int _selectedIndex = 0;
  DateTime? _catalogSavedAt;

  @override
  void initState() {
    super.initState();
    _loadCatalogSavedAt();
  }

  Future<void> _loadCatalogSavedAt() async {
    final savedAt = await MoiamovApiService.instance.lastSavedCatalogAt();
    if (!mounted) return;
    setState(() => _catalogSavedAt = savedAt);
  }

  String _skipCatalogLabel() {
    final title = 'settings_general_skip_catalog'.tr();
    final savedAt = _catalogSavedAt;
    if (savedAt == null) return title;
    final local = savedAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$title · $day/$month/${local.year}';
  }

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final tvSettings = context.watch<TvSettingsProvider>();
    final showCatalogFrequency =
        !tvSettings.skipCatalogUpdate && _catalogSavedAt != null;

    final items = <_SettingsMoviesSeriesItemType>[
      _SettingsMoviesSeriesItemType.skipCatalog,
      if (showCatalogFrequency) _SettingsMoviesSeriesItemType.catalogFrequency,
    ];

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(left: 4, right: 12, top: 8, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: 'settings_movies_series_title'.tr(),
              subtitle: 'settings_movies_series_subtitle'.tr(),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final targetHeight = (_windowSize * _itemExtent).clamp(
                    0.0,
                    constraints.maxHeight,
                  );
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: targetHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: TvWindowedList<_SettingsMoviesSeriesItemType>(
                          key: _listKey,
                          items: items,
                          windowSize: _windowSize,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                          },
                          itemBuilder: (
                            context,
                            item,
                            focusNode,
                            local,
                            global,
                            onKeyUp,
                            onKeyDown,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: _buildItem(
                                context: context,
                                item: item,
                                focusNode: focusNode,
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

  Widget _buildItem({
    required BuildContext context,
    required _SettingsMoviesSeriesItemType item,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _SettingsMoviesSeriesItemType.skipCatalog:
        final skipCatalog =
            context.watch<TvSettingsProvider>().skipCatalogUpdate;
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.cloudOffOutlined,
          label: _skipCatalogLabel(),
          description: 'settings_general_skip_catalog_desc'.tr(),
          value: skipCatalog,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setSkipCatalogUpdate(value);
          },
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsMoviesSeriesItemType.catalogFrequency:
        final frequency =
            context.watch<TvSettingsProvider>().catalogUpdateFrequency;
        return SettingsCatalogFrequencyRow(
          focusNode: focusNode,
          selected: frequency,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setCatalogUpdateFrequency(value);
          },
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}
