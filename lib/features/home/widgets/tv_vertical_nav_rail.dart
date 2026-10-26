import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/features/home/home_section.dart';
import 'package:moai3/features/home/widgets/tv_bottom_weather_pill.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Rail de navegación lateral vertical con destinos circulares compactos:
/// - Cápsula flotante continua centrada verticalmente.
/// - Destinos circulares con navegación D-Pad adaptada para Android TV.
class TvVerticalNavRail extends StatefulWidget {
  final HomeSection selected;
  final FocusScopeNode railScopeNode;
  final FocusNode railFocusNode;
  final ValueChanged<HomeSection> onSelected;
  final VoidCallback onFocusRight;

  const TvVerticalNavRail({
    super.key,
    required this.selected,
    required this.railScopeNode,
    required this.railFocusNode,
    required this.onSelected,
    required this.onFocusRight,
  });

  @override
  State<TvVerticalNavRail> createState() => _TvVerticalNavRailState();
}

class _TvVerticalNavRailState extends State<TvVerticalNavRail> {
  bool _isFocused = false;
  late HomeSection _focused;
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

  List<HomeSection> _getAvailableSections(bool isArcadeInstalled) {
    final movies = context.read<FeaturedMoviesProvider>();
    bool isVisible(HomeSection section) {
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
    }
  }

  void _moveFocusUp(bool isArcadeInstalled) {
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
            }
          });
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowRight) {
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MoaiGlass(
                      width: 48,
                      borderRadius: 24,
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
                // En el Inicio la hora y el clima ya están en el panel: arriba
                // va el logo. En las demás secciones, la píldora de siempre.
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: widget.selected == HomeSection.home
                        ? const _RailLogo(key: ValueKey('logo'))
                        : const TvBottomWeatherPill(key: ValueKey('reloj')),
                  ),
                ),
              ],
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
    final isHovered = _isFocused && _focused == section;

    final IconData iconData;
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
        iconData = isSelected
            ? MoaiIcons.railSeriesSelected
            : MoaiIcons.railSeries;
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

    final Color iconColor;

    if (isHovered) {
      iconColor = scheme.onPrimary;
    } else if (isSelected) {
      iconColor = scheme.onSurface;
    } else {
      iconColor = scheme.onSurfaceVariant;
    }

    Widget iconWidget = Icon(
      iconData,
      size: MoaiIconSizes.md,
      color: iconColor,
    );

    if (section == HomeSection.calendar && todayEvents > 0) {
      iconWidget = Badge(
        backgroundColor: scheme.tertiaryContainer,
        textColor: scheme.onTertiaryContainer,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9),
        offset: const Offset(3, -3),
        label: Text('$todayEvents'),
        child: iconWidget,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(scheme.primary, Colors.white, 0.22)!,
                      scheme.primary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: iconWidget,
              )
            : isSelected
            ? MoaiGlass(
                width: 40,
                height: 40,
                tint: scheme.primary,
                elevated: false,
                alignment: Alignment.center,
                child: iconWidget,
              )
            : SizedBox(width: 40, height: 40, child: Center(child: iconWidget)),
      ),
    );
  }
}

/// Logo de Moai, girado para leerse de abajo hacia arriba (como la pestaña
/// de los paneles), solo, en el lugar de la píldora del reloj y el clima.
class _RailLogo extends StatelessWidget {
  const _RailLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Sólo el logo, sin cristal alrededor.
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: RotatedBox(
          quarterTurns: 3,
          child: SvgPicture.asset(
            'assets/svgs/appLogo.svg',
            height: 20,
            colorFilter: ColorFilter.mode(scheme.onSurface, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
