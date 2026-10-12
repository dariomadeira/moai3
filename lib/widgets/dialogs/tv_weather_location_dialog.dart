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
  final GlobalKey<TvWindowedListState<WeatherLocationSearchResult>>
  _resultsListKey =
      GlobalKey<TvWindowedListState<WeatherLocationSearchResult>>();

  String _searchQuery = '';
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
    _autoBtnFocus.dispose();
    _searchBtnFocus.dispose();
    _closeBtnFocus.dispose();
    super.dispose();
  }

  Future<void> _openKeyboardAndSearch() async {
    final text = await TvTextField.open(
      context,
      title: 'weather_location_dialog_title'.tr(),
      initialValue: _searchQuery,
      hint: 'weather_location_search_hint'.tr(),
    );

    if (text == null || !mounted) return;
    final trimmed = text.trim();
    setState(() {
      _searchQuery = trimmed;
    });

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
      icon: Icons.check_circle_rounded,
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
      icon: Icons.my_location_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weatherProvider = context.watch<WeatherProvider>();
    final isAuto = weatherProvider.isAutoLocation;

    return TvDialog(
      width: 580,
      icon: Icons.location_on_outlined,
      iconColor: scheme.primary,
      iconBgColor: scheme.primary.withValues(alpha: 0.15),
      title: 'weather_location_dialog_title'.tr(),
      subtitle: 'weather_location_dialog_subtitle'.tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Botón para detección automática
          TvDialogButton(
            focusNode: _autoBtnFocus,
            label: isAuto
                ? 'weather_location_auto_active'.tr()
                : 'weather_location_auto_btn'.tr(),
            icon: Icons.my_location_rounded,
            variant: isAuto
                ? TvDialogButtonVariant.primary
                : TvDialogButtonVariant.neutral,
            onPressed: _resetToAuto,
            onKeyDown: () => _searchBtnFocus.requestFocus(),
          ),
          const SizedBox(height: 8),

          // 2. Botón interactivo para abrir teclado y buscar
          TvTile(
            focusNode: _searchBtnFocus,
            minHeight: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            label: _searchQuery.isEmpty
                ? 'weather_location_search_hint'.tr()
                : 'weather_location_search_prefix'.tr(
                    namedArgs: {'query': _searchQuery},
                  ),
            description: _searchQuery.isEmpty
                ? 'weather_location_search_desc_empty'.tr()
                : 'weather_location_search_desc_modify'.tr(),
            icon: Icons.search_rounded,
            onPressed: _openKeyboardAndSearch,
            onKeyUp: () => _autoBtnFocus.requestFocus(),
            onKeyDown: () {
              if (_results.isNotEmpty) {
                _resultsListKey.currentState?.ensureVisible(0);
              } else {
                _closeBtnFocus.requestFocus();
              }
            },
            trailingBuilder: (context, isFocused) {
              return Icon(
                Icons.keyboard_outlined,
                size: 20,
                color: isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
              );
            },
          ),
          const SizedBox(height: 8),

          // 3. Área de sugerencias / resultados
          _buildResultsArea(context, scheme),
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _closeBtnFocus,
          label: 'Cerrar',
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
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
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
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
              Icons.location_off_outlined,
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
      const itemExtent = 58.0;
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
          onFocusDownFromLast: () => _closeBtnFocus.requestFocus(),
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
                    minHeight: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    label: item.displayName,
                    description: item.subtitle,
                    icon: Icons.location_on_outlined,
                    onPressed: () => _selectLocation(item),
                    onKeyUp: onKeyUp,
                    onKeyDown: onKeyDown,
                    trailingBuilder: (context, isFocused) {
                      return Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: isFocused
                            ? scheme.onPrimary
                            : scheme.primary.withValues(alpha: 0.6),
                      );
                    },
                  ),
                );
              },
        ),
      );
    }

    // Estado inicial antes de realizar una búsqueda
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: scheme.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'weather_location_type_to_search'.tr(),
              style: MoaiText.body(
                context,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
