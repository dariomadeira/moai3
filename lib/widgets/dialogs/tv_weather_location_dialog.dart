import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/services/weather_service.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Diálogo modal estándar de TV para configurar la ubicación del clima
/// con búsqueda y autocompletado en tiempo real, soportando TvWindowedList con dots.
class TvWeatherLocationDialog extends StatefulWidget {
  const TvWeatherLocationDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvWeatherLocationDialog',
      builder: (_) => const TvWeatherLocationDialog(),
    );
  }

  @override
  State<TvWeatherLocationDialog> createState() =>
      _TvWeatherLocationDialogState();
}

class _TvWeatherLocationDialogState extends State<TvWeatherLocationDialog> {
  final FocusNode _autoBtnFocus = FocusNode(debugLabel: 'weather_auto_btn');
  final FocusNode _searchBtnFocus = FocusNode(debugLabel: 'weather_search_btn');
  final FocusNode _closeBtnFocus = FocusNode(debugLabel: 'weather_close_btn');
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<TvWindowedListState<WeatherLocationSearchResult>>
  _resultsListKey =
      GlobalKey<TvWindowedListState<WeatherLocationSearchResult>>();

  bool _isSearching = false;
  bool _hasSearched = false;
  List<WeatherLocationSearchResult> _results = [];
  int _selectedResultIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchBtnFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _autoBtnFocus.dispose();
    _searchBtnFocus.dispose();
    _closeBtnFocus.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _hasSearched = trimmed.isNotEmpty;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _selectedResultIndex = 0;
    });

    try {
      if (!mounted) return;
      final weatherProvider = context.read<WeatherProvider>();
      final items = await weatherProvider.service.searchLocations(trimmed);
      if (mounted) {
        setState(() {
          _results = items;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectLocation(WeatherLocationSearchResult loc) async {
    final weatherProvider = context.read<WeatherProvider>();
    await weatherProvider.setCustomLocation(loc);
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    MoaiSnackBar.show(
      context,
      message: 'weather_location_configured'.tr(
        namedArgs: {'location': loc.displayName},
      ),
      icon: MoaiIcons.checkCircleRounded,
    );
  }

  Future<void> _resetToAuto() async {
    final weatherProvider = context.read<WeatherProvider>();
    await weatherProvider.resetToAutoLocation();
    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();
    MoaiSnackBar.show(
      context,
      message: 'weather_location_reset_auto'.tr(),
      icon: MoaiIcons.myLocationRounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weatherProvider = context.watch<WeatherProvider>();
    final isAuto = weatherProvider.isAutoLocation;

    return TvDialog(
      width: 580,
      icon: MoaiIcons.locationOnOutlined,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: 'weather_location_dialog_title'.tr(),
      subtitle: 'weather_location_dialog_subtitle'.tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Campo interactivo estándar (TvTextField) idéntico a Buscar
          TvTextField(
            controller: _searchController,
            focusNode: _searchBtnFocus,
            label: 'weather_location_search_hint'.tr(),
            hint: 'search_field_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            textInputAction: TvTextInputAction.search,
            dense: true,
            leadingIcon: MoaiIcons.keyboardAltOutlined,
            onChanged: (val) => _performSearch(val),
            onSubmitted: (val) {
              _performSearch(val);
              if (_results.isNotEmpty) {
                _resultsListKey.currentState?.ensureVisible(0);
              }
            },
            onFocusDown: () {
              if (_results.isNotEmpty) {
                _resultsListKey.currentState?.ensureVisible(0);
              } else {
                _autoBtnFocus.requestFocus();
              }
            },
          ),
          if (_isSearching || _hasSearched) ...[
            const SizedBox(height: 16),
            _buildResultsArea(context, scheme),
          ],
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _autoBtnFocus,
          label: isAuto
              ? 'weather_location_auto_active'.tr()
              : 'weather_location_auto_btn'.tr(),
          icon: MoaiIcons.myLocationRounded,
          variant: isAuto
              ? TvDialogButtonVariant.primary
              : TvDialogButtonVariant.neutral,
          onPressed: _resetToAuto,
          onKeyRight: () => _closeBtnFocus.requestFocus(),
          onKeyUp: () {
            if (_results.isNotEmpty) {
              _resultsListKey.currentState?.ensureVisible(_results.length - 1);
            } else {
              _searchBtnFocus.requestFocus();
            }
          },
        ),
        TvDialogButton(
          focusNode: _closeBtnFocus,
          label: 'common_close'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          onKeyLeft: () => _autoBtnFocus.requestFocus(),
          onKeyUp: () {
            if (_results.isNotEmpty) {
              _resultsListKey.currentState?.ensureVisible(_results.length - 1);
            } else {
              _searchBtnFocus.requestFocus();
            }
          },
        ),
      ],
    );
  }

  Widget _buildResultsArea(BuildContext context, ColorScheme scheme) {
    if (_isSearching) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'weather_location_searching'.tr(),
              style: MoaiText.body(
                context,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.locationOffOutlined,
              size: 30,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'weather_location_no_results'.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isNotEmpty) {
      const windowSize = 3;
      const itemExtent = 72.0;
      final targetHeight = (windowSize * itemExtent);

      return SizedBox(
        height: targetHeight,
        child: TvWindowedList<WeatherLocationSearchResult>(
          key: _resultsListKey,
          items: _results,
          windowSize: windowSize,
          itemExtent: itemExtent,
          showScrollDots: true,
          initialGlobalIndex: _selectedResultIndex,
          onFocusUpFromFirst: () => _searchBtnFocus.requestFocus(),
          onFocusDownFromLast: () => _autoBtnFocus.requestFocus(),
          onFocusedGlobalIndex: (idx) => _selectedResultIndex = idx,
          itemBuilder:
              (
                context,
                item,
                focusNode,
                localIndex,
                globalIndex,
                onKeyUp,
                onKeyDown,
              ) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: TvTile(
                    focusNode: focusNode,
                    minHeight: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    label: item.displayName,
                    description: item.subtitle,
                    icon: MoaiIcons.weatherLocationItem,
                    onPressed: () => _selectLocation(item),
                    onKeyUp: onKeyUp,
                    onKeyDown: onKeyDown,
                  ),
                );
              },
        ),
      );
    }

    // Estado inicial antes de realizar una búsqueda (el helperText ya vive en TvTextField)
    return const SizedBox.shrink();
  }
}
