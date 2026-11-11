import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/settings/widgets/settings_audio_language_row.dart';
import 'package:moai3/features/settings/widgets/settings_catalog_frequency_row.dart';
import 'package:moai3/features/settings/widgets/settings_subtitle_language_row.dart';
import 'package:moai3/features/settings/widgets/settings_subtitle_size_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:provider/provider.dart';
import 'package:moai3/utils/moai_formats.dart';

enum _SettingsMoviesSeriesItemType {
  audioLanguage,
  subtitleLanguage,
  subtitleSize,
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

  /// La fecha de la última actualización va en la descripción: pegada al
  /// título no entraba al lado del selector y se cortaba siempre.
  String? _catalogFrequencyDescription() {
    final savedAt = _catalogSavedAt;
    if (savedAt == null) return null;
    return LocaleKeys.settings_general_catalog_frequency_last.tr(
      namedArgs: {'date': MoaiFormats.date(savedAt.toLocal())},
    );
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
        padding: TvPanelSlots.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: LocaleKeys.settings_movies_series_title.tr(),
              subtitle: LocaleKeys.settings_movies_series_subtitle.tr(),
              titleShader: HomeClock.timeShader,
            ),
            // Igual que Agenda › Suscripciones: los 6 lugares reparten el
            // alto bajo el encabezado.
            TvPanelSlots.belowHeader,
            Expanded(
              child: LayoutBuilder(
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
                        child: TvWindowedList<_SettingsMoviesSeriesItemType>(
                          key: _listKey,
                          // La entrada de foco la decide el área (rail →, cambio de panel).
                          focusOnMount: false,
                          items: items,
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
                                item,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: TvPanelSlots.gap / 2,
                                  ),
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
        final language = context.select(
          (TvSettingsProvider s) => s.movieAudioLanguage,
        );
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
        final subtitles = context
            .watch<TvSettingsProvider>()
            .movieSubtitleLanguage;
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
      case _SettingsMoviesSeriesItemType.subtitleSize:
        final size = context.select(
          (TvSettingsProvider s) => s.movieSubtitleSize,
        );
        return SettingsSubtitleSizeRow(
          focusNode: focusNode,
          selected: size,
          onKeyLeft: widget.onKeyLeft,
          onKeyRight: widget.onKeyRight,
          onChanged: (value) {
            context.read<TvSettingsProvider>().setMovieSubtitleSize(value);
          },
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _SettingsMoviesSeriesItemType.homeTrailers:
        final show = context.select(
          (TvSettingsProvider s) => s.showHomeTrailers,
        );
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
        final frequency = context
            .watch<TvSettingsProvider>()
            .catalogUpdateFrequency;
        return SettingsCatalogFrequencyRow(
          focusNode: focusNode,
          description: _catalogFrequencyDescription(),
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
