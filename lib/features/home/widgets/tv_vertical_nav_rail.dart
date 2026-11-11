import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/features/home/home_section.dart';
import 'package:moai3/features/home/widgets/home_arcade_card.dart';
import 'package:moai3/features/home/widgets/home_discounts_card.dart';
import 'package:moai3/features/home/widgets/home_events_card.dart';
import 'package:moai3/features/home/widgets/home_watchlist_big_card.dart';
import 'package:moai3/theme/moai_focus_style.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_count_badge.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';

/// Rail de navegación lateral vertical con destinos circulares compactos:
/// - Cápsula flotante continua centrada verticalmente.
/// - Destinos circulares con navegación D-Pad adaptada para Android TV.
class TvVerticalNavRail extends StatefulWidget {
  final HomeSection selected;
  final FocusScopeNode railScopeNode;
  final FocusNode railFocusNode;
  final ValueChanged<HomeSection> onSelected;
  final VoidCallback onFocusRight;

  /// Botón de salir (abajo de todo). El Inicio pide la confirmación
  /// (snack + segundo toque).
  final VoidCallback onExit;

  const TvVerticalNavRail({
    super.key,
    required this.selected,
    required this.railScopeNode,
    required this.railFocusNode,
    required this.onSelected,
    required this.onFocusRight,
    required this.onExit,
  });

  /// Color de TV en el rail con foco: verde esmeralda (distinto del verde
  /// de "Instalado"). Sólo en el rail: adentro de TV todo va en el acento
  /// (2026-11-10).
  static const Color tvColor = Color(0xFF059669);

  /// Color de Series en el rail: cian (frío, lejos del naranja de Películas).
  static const Color seriesColor = Color(0xFF0891B2);

  /// Íconos sin foco: casi negro sobre el vidrio (claro en el oscuro). Las
  /// pestañas de TV lo comparten.
  static Color idleIconColorOf(BuildContext context) =>
      MoaiPalette.of(context).inkIdle;

  @override
  State<TvVerticalNavRail> createState() => _TvVerticalNavRailState();
}

class _TvVerticalNavRailState extends State<TvVerticalNavRail> {
  bool _isFocused = false;
  late HomeSection _focused;

  /// El foco está en el botón de salir (debajo de las secciones).
  bool _exitFocused = false;
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;

  @override
  void initState() {
    super.initState();
    _focused = widget.selected;
    _arcadePlugin.addListener(_onPluginStateChanged);
  }

  void _onPluginStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _arcadePlugin.removeListener(_onPluginStateChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TvVerticalNavRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFocused) {
      _focused = widget.selected;
    }
  }

  /// Destacados, Películas y Series dependen del login y el catálogo del arranque.
  static const _catalogSections = {
    HomeSection.featured: FeaturedMoviesProvider.sectionFeatured,
    HomeSection.movies: FeaturedMoviesProvider.sectionMovies,
    HomeSection.series: FeaturedMoviesProvider.sectionSeries,
  };

  /// Ocultas temporalmente. Series volvió el 2026-11-09.
  static const _hiddenSections = {HomeSection.featured, HomeSection.liveTv};

  List<HomeSection> _getAvailableSections(bool isArcadeInstalled) {
    final movies = context.read<FeaturedMoviesProvider>();
    bool isVisible(HomeSection section) {
      if (_hiddenSections.contains(section)) return false;
      if (section == HomeSection.arcade) return isArcadeInstalled;
      final catalog = _catalogSections[section];
      return catalog == null || movies.isSectionAvailable(catalog);
    }

    return HomeSection.values.where(isVisible).toList();
  }

  void _moveFocusDown(bool isArcadeInstalled) {
    final available = _getAvailableSections(isArcadeInstalled);
    final currentIndex = available.indexOf(_focused);
    if (currentIndex != -1 && currentIndex < available.length - 1) {
      setState(() => _focused = available[currentIndex + 1]);
    } else if (currentIndex == available.length - 1) {
      setState(() => _exitFocused = true);
    }
  }

  void _moveFocusUp(bool isArcadeInstalled) {
    if (_exitFocused) {
      setState(() => _exitFocused = false);
      return;
    }
    final available = _getAvailableSections(isArcadeInstalled);
    final currentIndex = available.indexOf(_focused);
    if (currentIndex > 0) {
      setState(() => _focused = available[currentIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isArcadeInstalled = _arcadePlugin.isInstalled;
    // Reconstruye el rail cuando el arranque define las secciones del catálogo.
    context.select((FeaturedMoviesProvider p) => p.availableSections);
    final availableSections = _getAvailableSections(isArcadeInstalled);

    final todayEvents = context.select(
      (CalendarProvider p) => p.todayEventCount,
    );

    return FocusScope(
      node: widget.railScopeNode,
      child: Focus(
        focusNode: widget.railFocusNode,
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
            if (!focused) {
              _focused = widget.selected;
              _exitFocused = false;
            }
          });
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowRight) {
            if (_exitFocused) {
              setState(() => _exitFocused = false);
              widget.onFocusRight();
              return KeyEventResult.handled;
            }
            if (_focused != widget.selected) {
              widget.onSelected(_focused);
            }
            widget.onFocusRight();
            return KeyEventResult.handled;
          }

          if (key == LogicalKeyboardKey.arrowDown) {
            _moveFocusDown(isArcadeInstalled);
            return KeyEventResult.handled;
          }

          if (key == LogicalKeyboardKey.arrowUp) {
            _moveFocusUp(isArcadeInstalled);
            return KeyEventResult.handled;
          }

          if (TvKeyHandler.isActionKey(key)) {
            if (_exitFocused) {
              widget.onExit();
              return KeyEventResult.handled;
            }
            if (_focused != widget.selected) {
              widget.onSelected(_focused);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !widget.railFocusNode.hasFocus) {
                  widget.railFocusNode.requestFocus();
                }
              });
            }
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: SizedBox(
            width: 48,
            // Sólo los íconos, centrados en vertical, con el vidrio esmerilado
            // del panel. La hora y el clima están en el Inicio.
            // El botón de salir va aparte, abajo de todo (alineado con el
            // borde de abajo de los paneles).
            child: Column(
              children: [
                Expanded(
                  child: Align(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: MoaiGlass(
                        width: 48,
                        borderRadius: 24,
                        frosted: true,
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (
                              int i = 0;
                              i < availableSections.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 5),
                              _buildRailDestination(
                                availableSections[i],
                                scheme,
                                todayEvents,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildExitButton(scheme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Salir: una cápsula redonda del mismo vidrio que el rail, con el ícono
  /// casi negro; con foco, en rojo con brillo y halo (como el tacho de
  /// borrar), porque cierra la app.
  Widget _buildExitButton(ColorScheme scheme) {
    final focused = _isFocused && _exitFocused;
    return Semantics(
      label: LocaleKeys.home_rail_exit_title.tr(),
      button: true,
      child: GestureDetector(
        onTap: () {
          setState(() => _exitFocused = true);
          widget.railFocusNode.requestFocus();
          widget.onExit();
        },
        child: MoaiGlass(
          width: 48,
          height: 48,
          borderRadius: 24,
          frosted: true,
          padding: const EdgeInsets.all(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 40,
            height: 40,
            // Sin foco, nada: se ve el vidrio de la cápsula.
            decoration: focused
                ? moaiGlassButtonDecoration(
                    scheme,
                    focused: true,
                    accent: scheme.error,
                  )
                : const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
            alignment: Alignment.center,
            child: Icon(
              MoaiIcons.exitApp,
              size: MoaiIconSizes.md,
              // Sin foco, en rojo: avisa que sale de la app.
              color: focused ? scheme.onError : scheme.error,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestination(
    HomeSection section,
    ColorScheme scheme,
    int todayEvents,
  ) {
    final isSelected = widget.selected == section;
    final isHovered = _isFocused && !_exitFocused && _focused == section;

    // Series no tiene [IconData]: va con su SVG ([MoaiSvgIcon]).
    IconData? iconData;
    final String labelKey;

    switch (section) {
      case HomeSection.home:
        iconData = isSelected ? MoaiIcons.railHomeSelected : MoaiIcons.railHome;
        labelKey = LocaleKeys.home_rail_home_title;
        break;
      case HomeSection.tv:
        iconData = isSelected ? MoaiIcons.railTvSelected : MoaiIcons.railTv;
        labelKey = LocaleKeys.home_rail_tv_title;
        break;
      case HomeSection.liveTv:
        iconData = MoaiIcons.railLiveTv;
        labelKey = LocaleKeys.home_rail_live_tv_title;
        break;
      case HomeSection.featured:
        iconData = isSelected
            ? MoaiIcons.railFeaturedSelected
            : MoaiIcons.railFeatured;
        labelKey = LocaleKeys.home_rail_featured_title;
        break;
      case HomeSection.movies:
        iconData = isSelected
            ? MoaiIcons.railMoviesSelected
            : MoaiIcons.railMovies;
        labelKey = LocaleKeys.home_rail_movies_title;
        break;
      case HomeSection.series:
        labelKey = LocaleKeys.home_rail_series_title;
        break;
      case HomeSection.calendar:
        iconData = isSelected
            ? MoaiIcons.railCalendarSelected
            : MoaiIcons.railCalendar;
        labelKey = LocaleKeys.home_rail_calendar_title;
        break;
      case HomeSection.discounts:
        iconData = isSelected
            ? MoaiIcons.railDiscountsSelected
            : MoaiIcons.railDiscounts;
        labelKey = LocaleKeys.home_rail_discounts_title;
        break;
      case HomeSection.arcade:
        iconData = isSelected
            ? MoaiIcons.railArcadeSelected
            : MoaiIcons.railArcade;
        labelKey = LocaleKeys.home_rail_arcade_title;
        break;
      case HomeSection.settings:
        iconData = isSelected
            ? MoaiIcons.railSettingsSelected
            : MoaiIcons.railSettings;
        labelKey = LocaleKeys.home_rail_settings_title;
        break;
    }

    // REDISEÑO: sin foco, casi negro (antes el gris 0xFF3C4250 de la
    // pestaña del panel, `CollapsedPanelTabPreview`, que se veía lavado).
    // Con foco, algunas secciones usan su color en vez del acento:
    // Películas el de su tarjeta "Marcadas" del Inicio, Agenda el de la de
    // eventos, Descuentos el de la suya y Arcade el de sus íconos; TV un
    // verde esmeralda y Series un cian (frío, lejos del naranja de
    // Películas). Inicio y Ajustes, el acento.
    final sectionColor = switch (section) {
      HomeSection.tv || HomeSection.liveTv => TvVerticalNavRail.tvColor,
      HomeSection.movies => HomeWatchlistBigCard.color,
      HomeSection.series => TvVerticalNavRail.seriesColor,
      HomeSection.calendar => HomeEventsCard.liveColor,
      HomeSection.discounts => HomeDiscountsCard.color,
      HomeSection.arcade => HomeArcadeCard.color,
      _ => null,
    };
    // El seleccionado sin foco conserva el color de su sección sobre el
    // vidrio blanco (TV en verde…); los demás, casi negro.
    final iconColor = isHovered
        ? (sectionColor != null ? Colors.white : scheme.onPrimary)
        : isSelected
        ? (sectionColor ?? scheme.primary)
        : TvVerticalNavRail.idleIconColorOf(context);

    Widget iconWidget = iconData == null
        ? MoaiSvgIcon(
            MoaiIcons.seriesSvg,
            size: MoaiIconSizes.md,
            color: iconColor,
          )
        : Icon(iconData, size: MoaiIconSizes.md, color: iconColor);

    if (section == HomeSection.calendar && todayEvents > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            top: -6,
            right: -8,
            child: MoaiCountBadge(count: todayEvents),
          ),
        ],
      );
    }

    // El rail es solo íconos: el título va como etiqueta de accesibilidad.
    return Semantics(
      label: labelKey.tr(),
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: () {
          setState(() => _focused = section);
          widget.onSelected(section);
          widget.railFocusNode.requestFocus();
        },
        borderRadius: BorderRadius.circular(20),
        child: isHovered
            // Foco: primario sólido con brillo arriba y halo, para que se
            // lea bien a distancia.
            ? Container(
                width: 40,
                height: 40,
                decoration: MoaiFocusStyle.decoration(
                  scheme,
                  color: sectionColor,
                ),
                alignment: Alignment.center,
                child: iconWidget,
              )
            // Seleccionado: el vidrio blanco con filo de luz del botón
            // "Jugar" sin foco.
            : isSelected
            ? Container(
                width: 40,
                height: 40,
                decoration: moaiGlassButtonDecoration(scheme, focused: false),
                alignment: Alignment.center,
                child: iconWidget,
              )
            : SizedBox(width: 40, height: 40, child: Center(child: iconWidget)),
      ),
    );
  }
}
