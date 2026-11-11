import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moai3/config/app_info.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/utils/moai_formats.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/update_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/widgets/tv_common/tv_value_chip.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

enum _AboutItemType { channelsLoaded, moviesInLibrary, checkUpdates }

class SettingsAboutPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final int initialIndex;
  final ValueChanged<int>? onSelectedIndexChanged;

  const SettingsAboutPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    this.initialIndex = 0,
    this.onSelectedIndexChanged,
  });

  @override
  State<SettingsAboutPanel> createState() => SettingsAboutPanelState();
}

class SettingsAboutPanelState extends State<SettingsAboutPanel> {
  /// Lugares para las opciones: el primero de los 6 es la marca.
  static const int _windowSize = TvPanelSlots.count - 1;

  final _listKey = GlobalKey<TvWindowedListState<_AboutItemType>>();
  late int _selectedIndex = widget.initialIndex;
  bool _isChecking = false;
  String? _statusChip;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  @override
  void initState() {
    super.initState();
    // El total de la biblioteca se pide recién al abrir Acerca de.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<FeaturedMoviesProvider?>()?.loadLibraryTotal());
    });
  }

  Future<void> _checkUpdate() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _statusChip = null;
    });

    // PRUEBA: con [UpdateDialog.previewInDebug] (sólo en debug) se abre el
    // modal con una versión de mentira para ver cómo queda.
    final updateInfo = UpdateDialog.previewInDebug && kDebugMode
        ? UpdateDialog.previewInfo
        : await UpdateService.checkForUpdate();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });

    if (updateInfo != null) {
      unawaited(UpdateDialog.show(context, updateInfo));
    } else {
      setState(() {
        _statusChip = LocaleKeys.settings_about_up_to_date.tr();
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _statusChip = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final (channelCount, isLoading) = context.select(
      (ChannelProvider p) => (p.allChannels.length, p.isLoadingChannels),
    );

    final String valueText;
    if (channelCount > 0) {
      valueText = LocaleKeys.home_channels_count.tr(
        namedArgs: {'count': '$channelCount'},
      );
    } else if (isLoading) {
      valueText = LocaleKeys.settings_about_loading.tr();
    } else {
      valueText = LocaleKeys.settings_about_empty.tr();
    }

    // Películas sólo con login y catálogo (como en el rail).
    // La fila sólo aparece cuando ya hay un total mayor que cero (ni
    // "cargando" ni 0 ni "—").
    final (moviesAvailable, moviesTotal) = context.select(
      (FeaturedMoviesProvider? p) => (
        p?.isSectionAvailable(FeaturedMoviesProvider.sectionMovies) ?? false,
        p?.libraryTotal,
      ),
    );
    final showMovies =
        moviesAvailable && moviesTotal != null && moviesTotal > 0;
    final moviesText = showMovies
        ? LocaleKeys.movies_count.tr(
            namedArgs: {'count': MoaiFormats.thousands(moviesTotal)},
          )
        : '';

    final items = [
      for (final item in _AboutItemType.values)
        if (item != _AboutItemType.moviesInLibrary || showMovies) item,
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
        padding: TvPanelSlots.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TvPanelHeader(
              title: LocaleKeys.settings_about_title.tr(),
              subtitle: LocaleKeys.settings_about_subtitle.tr(),
              titleShader: HomeClock.timeShader,
            ),
            TvPanelSlots.belowHeader,
            // La marca ocupa el primer lugar de los 6 y las opciones los
            // otros 5: las fichas miden lo mismo que en los demás paneles.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemExtent = TvPanelSlots.extentFor(
                    constraints.maxHeight,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TvPanelSlots.slot(
                        extent: itemExtent,
                        child: _AboutBrand(height: itemExtent),
                      ),
                      SizedBox(
                        height: (_windowSize * itemExtent).clamp(
                          0.0,
                          (constraints.maxHeight - itemExtent).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: TvWindowedList<_AboutItemType>(
                            key: _listKey,
                            // La entrada de foco la decide el área (rail →, cambio de panel).
                            focusOnMount: false,
                            items: items,
                            windowSize: _windowSize,
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
                                      valueText: valueText,
                                      moviesText: moviesText,
                                      scheme: scheme,
                                      focusNode: focusNode,
                                      onKeyUp: onKeyUp,
                                      onKeyDown: onKeyDown,
                                    ),
                                  );
                                },
                          ),
                        ),
                      ),
                    ],
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
    required _AboutItemType item,
    required String valueText,
    required String moviesText,
    required ColorScheme scheme,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _AboutItemType.channelsLoaded:
        return TvTile(
          focusNode: focusNode,
          label: LocaleKeys.settings_about_channels_loaded.tr(),
          icon: MoaiIcons.channelGuide,
          onKeyLeft: widget.onKeyLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            return TvValueChip(text: valueText, isFocused: isFocused);
          },
        );
      case _AboutItemType.moviesInLibrary:
        return TvTile(
          focusNode: focusNode,
          label: LocaleKeys.settings_about_movies.tr(),
          icon: MoaiIcons.vodMovie,
          onKeyLeft: widget.onKeyLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
            return TvValueChip(text: moviesText, isFocused: isFocused);
          },
        );
      case _AboutItemType.checkUpdates:
        return TvTile(
          focusNode: focusNode,
          icon: MoaiIcons.appUpdate,
          label: LocaleKeys.settings_about_check_updates.tr(),
          description: LocaleKeys.settings_about_check_updates_desc.tr(),
          onKeyLeft: widget.onKeyLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onPressed: _checkUpdate,
          trailingBuilder: (context, isFocused) {
            if (_isChecking) {
              return SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            if (_statusChip != null) {
              // La misma etiqueta de cristal que los contadores de canales y
              // películas.
              return TvValueChip(text: _statusChip!, isFocused: isFocused);
            }
            return Icon(
              MoaiIcons.chevronRight,
              color: isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
              size: MoaiIconSizes.lg,
            );
          },
        );
    }
  }
}

/// La marca de Acerca de (imagen, logo y versión), del alto de un lugar de
/// la lista. Angosto, sin la imagen.
class _AboutBrand extends StatelessWidget {
  const _AboutBrand({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final imageHeight = height - TvPanelSlots.gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final meta = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svgs/appLogo.svg',
              height: 24,
              // Del mismo gris oscuro que el logo del Inicio.
              colorFilter: ColorFilter.mode(
                MoaiPalette.of(context).inkMuted,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.settings_about_version.tr(
                namedArgs: {'version': AppInfo.version},
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 220) return meta;
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: [
              Image.asset(
                'assets/images/moaiAbout.png',
                height: imageHeight,
                cacheHeight:
                    (imageHeight * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 16),
              Expanded(child: meta),
            ],
          ),
        );
      },
    );
  }
}
