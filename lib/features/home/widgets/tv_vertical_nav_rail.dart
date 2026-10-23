import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/features/home/widgets/tv_bottom_weather_pill.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Rail de navegación lateral vertical con destinos circulares compactos:
/// - Cápsula flotante continua centrada verticalmente.
/// - Destinos circulares con navegación D-Pad adaptada para Android TV.
class TvVerticalNavRail extends StatefulWidget {
  final int selectedIndex;
  final FocusScopeNode railScopeNode;
  final FocusNode railFocusNode;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onFocusRight;

  const TvVerticalNavRail({
    super.key,
    required this.selectedIndex,
    required this.railScopeNode,
    required this.railFocusNode,
    required this.onIndexChanged,
    required this.onFocusRight,
  });

  @override
  State<TvVerticalNavRail> createState() => _TvVerticalNavRailState();
}

class _TvVerticalNavRailState extends State<TvVerticalNavRail> {
  static const int sectionHome = 0;
  static const int sectionTv = 1;
  static const int sectionFeatured = 2;
  static const int sectionMovies = 3;
  static const int sectionSeries = 4;
  static const int sectionCalendar = 5;
  static const int sectionArcade = 6;
  static const int sectionSettings = 7;

  bool _isFocused = false;
  late int _focusedIndex;
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.selectedIndex;
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
      _focusedIndex = widget.selectedIndex;
    }
  }

  List<int> _getAvailableSections(bool isArcadeInstalled) {
    if (isArcadeInstalled) {
      return const [
        sectionHome,
        sectionTv,
        sectionFeatured,
        sectionMovies,
        sectionSeries,
        sectionCalendar,
        sectionArcade,
        sectionSettings,
      ];
    }
    return const [
      sectionHome,
      sectionTv,
      sectionFeatured,
      sectionMovies,
      sectionSeries,
      sectionCalendar,
      sectionSettings,
    ];
  }

  void _moveFocusDown(bool isArcadeInstalled) {
    final available = _getAvailableSections(isArcadeInstalled);
    final currentIndex = available.indexOf(_focusedIndex);
    if (currentIndex != -1 && currentIndex < available.length - 1) {
      setState(() => _focusedIndex = available[currentIndex + 1]);
    }
  }

  void _moveFocusUp(bool isArcadeInstalled) {
    final available = _getAvailableSections(isArcadeInstalled);
    final currentIndex = available.indexOf(_focusedIndex);
    if (currentIndex > 0) {
      setState(() => _focusedIndex = available[currentIndex - 1]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isArcadeInstalled = _arcadePlugin.isInstalled;
    final availableSections = _getAvailableSections(isArcadeInstalled);

    final todayEvents = context.select(
      (CalendarProvider p) => p.todayEventCount,
    );

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.48);

    return FocusScope(
      node: widget.railScopeNode,
      child: Focus(
        focusNode: widget.railFocusNode,
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
            if (!focused) {
              _focusedIndex = widget.selectedIndex;
            }
          });
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowRight) {
            if (_focusedIndex != widget.selectedIndex) {
              widget.onIndexChanged(_focusedIndex);
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
            if (_focusedIndex != widget.selectedIndex) {
              widget.onIndexChanged(_focusedIndex);
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
                    child: Container(
                      width: 48,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < availableSections.length; i++) ...[
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
                const Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: TvBottomWeatherPill(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestination(
    int section,
    ColorScheme scheme,
    int todayEvents,
  ) {
    final isSelected = widget.selectedIndex == section;
    final isHovered = _isFocused && _focusedIndex == section;

    final IconData iconData;
    final String labelKey;

    switch (section) {
      case sectionHome:
        iconData =
            isSelected ? MoaiIcons.railHomeSelected : MoaiIcons.railHome;
        labelKey = LocaleKeys.home_rail_home_title;
        break;
      case sectionTv:
        iconData = isSelected ? MoaiIcons.railTvSelected : MoaiIcons.railTv;
        labelKey = LocaleKeys.home_rail_tv_title;
        break;
      case sectionFeatured:
        iconData = isSelected
            ? MoaiIcons.railFeaturedSelected
            : MoaiIcons.railFeatured;
        labelKey = LocaleKeys.home_rail_featured_title;
        break;
      case sectionMovies:
        iconData =
            isSelected ? MoaiIcons.railMoviesSelected : MoaiIcons.railMovies;
        labelKey = LocaleKeys.home_rail_movies_title;
        break;
      case sectionSeries:
        iconData =
            isSelected ? MoaiIcons.railSeriesSelected : MoaiIcons.railSeries;
        labelKey = LocaleKeys.home_rail_series_title;
        break;
      case sectionCalendar:
        iconData =
            isSelected ? MoaiIcons.railCalendarSelected : MoaiIcons.railCalendar;
        labelKey = LocaleKeys.home_rail_calendar_title;
        break;
      case sectionArcade:
        iconData =
            isSelected ? MoaiIcons.railArcadeSelected : MoaiIcons.railArcade;
        labelKey = LocaleKeys.home_rail_arcade_title;
        break;
      case sectionSettings:
      default:
        iconData =
            isSelected ? MoaiIcons.railSettingsSelected : MoaiIcons.railSettings;
        labelKey = LocaleKeys.home_rail_settings_title;
        break;
    }

    final Color pillColor;
    final Color iconColor;

    if (isHovered) {
      pillColor = scheme.primary;
      iconColor = scheme.onPrimary;
    } else if (isSelected) {
      pillColor = scheme.primaryContainer;
      iconColor = scheme.onPrimaryContainer;
    } else {
      pillColor = Colors.transparent;
      iconColor = scheme.onSurfaceVariant;
    }

    Widget iconWidget = Icon(
      iconData,
      size: 20,
      color: iconColor,
    );

    if (section == sectionCalendar && todayEvents > 0) {
      iconWidget = Badge(
        backgroundColor: scheme.tertiaryContainer,
        textColor: scheme.onTertiaryContainer,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 9,
        ),
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
          setState(() => _focusedIndex = section);
          widget.onIndexChanged(section);
          widget.railFocusNode.requestFocus();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: pillColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: iconWidget,
        ),
      ),
    );
  }
}


