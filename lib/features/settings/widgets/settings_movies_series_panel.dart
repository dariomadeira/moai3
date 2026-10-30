import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_audio_language_row.dart';
import 'package:moai3/features/settings/widgets/settings_catalog_frequency_row.dart';
import 'package:moai3/features/settings/widgets/settings_subtitle_language_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:provider/provider.dart';
import 'package:moai3/utils/moai_formats.dart';

enum _SettingsMoviesSeriesItemType {
  audioLanguage,
  subtitleLanguage,
  homeTrailers,
  catalogFrequency,
}

class SettingsMoviesSeriesPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsMoviesSeriesPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
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
  late int _selectedIndex = widget.initialIndex;
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

  String _catalogFrequencyLabel() {
    final title = LocaleKeys.settings_general_catalog_frequency.tr();
    final savedAt = _catalogSavedAt;
    if (savedAt == null) return title;
    return '$title · ${MoaiFormats.date(savedAt.toLocal())}';
  }

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    const items = _SettingsMoviesSeriesItemType.values;

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
              title: LocaleKeys.settings_movies_series_title.tr(),
              subtitle: LocaleKeys.settings_movies_series_subtitle.tr(),
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
                          // La entrada de foco la decide el área (rail →, cambio de panel).
                          focusOnMount: false,
                          items: items,
                          itemExtent: _itemExtent,
                          showScrollDots: true,
                          initialGlobalIndex: _selectedIndex,
                          onFocusedGlobalIndex: (idx) {
                            _selectedIndex = idx;
                            widget.onSelectedIndexChanged?.call(idx);
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
      case _SettingsMoviesSeriesItemType.audioLanguage:
        final language =
            context.watch<TvSettingsProvider>().movieAudioLanguage;
        return SettingsAudioLanguageRow(
          focusNode: focusNode,
          selected: language,
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setMovieAudioLanguage(value);
          },
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsMoviesSeriesItemType.subtitleLanguage:
        final subtitles =
            context.watch<TvSettingsProvider>().movieSubtitleLanguage;
        return SettingsSubtitleLanguageRow(
          focusNode: focusNode,
          selected: subtitles,
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setMovieSubtitleLanguage(value);
          },
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsMoviesSeriesItemType.homeTrailers:
        final show = context.watch<TvSettingsProvider>().showHomeTrailers;
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.vodTrailer,
          label: LocaleKeys.settings_movies_home_trailers.tr(),
          description: LocaleKeys.settings_movies_home_trailers_desc.tr(),
          value: show,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setShowHomeTrailers(value);
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
          label: _catalogFrequencyLabel(),
          selected: frequency,
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setCatalogUpdateFrequency(value);
          },
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}
