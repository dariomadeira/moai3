import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_vertical_clock_pill.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Rail lateral: TV, Películas, Agenda, Arcade (si instalado) y Ajustes.
class NavigationRailSection extends StatefulWidget {
  final int selectedIndex;
  final FocusScopeNode railScopeNode;
  final FocusNode railFocusNode;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onFocusRight;

  const NavigationRailSection({
    super.key,
    required this.selectedIndex,
    required this.railScopeNode,
    required this.railFocusNode,
    required this.onIndexChanged,
    required this.onFocusRight,
  });

  @override
  State<NavigationRailSection> createState() => _NavigationRailSectionState();
}

class _NavigationRailSectionState extends State<NavigationRailSection> {
  static const int _sectionTv = 0;
  static const int _sectionMovies = 1;
  static const int _sectionCalendar = 2;
  static const int _sectionArcade = 3;
  static const int _sectionSettings = 4;

  bool _isFocused = false;
  late int _focusedIndex;
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;

  int _toRailIndex(int selected) => selected;
  int _toSelectedIndex(int rail) => rail;

  @override
  void initState() {
    super.initState();
    _focusedIndex = _toRailIndex(widget.selectedIndex);
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
  void didUpdateWidget(covariant NavigationRailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFocused) {
      _focusedIndex = _toRailIndex(widget.selectedIndex);
    }
  }

  void _moveFocusDown({required bool isArcadeInstalled}) {
    if (isArcadeInstalled) {
      if (_focusedIndex < _sectionSettings) {
        setState(() => _focusedIndex++);
      }
      return;
    }
    // Sin Arcade: 0 ↔ 1 ↔ 2 ↔ 4
    if (_focusedIndex == _sectionTv) {
      setState(() => _focusedIndex = _sectionMovies);
    } else if (_focusedIndex == _sectionMovies) {
      setState(() => _focusedIndex = _sectionCalendar);
    } else if (_focusedIndex == _sectionCalendar) {
      setState(() => _focusedIndex = _sectionSettings);
    }
  }

  void _moveFocusUp({required bool isArcadeInstalled}) {
    if (isArcadeInstalled) {
      if (_focusedIndex > _sectionTv) {
        setState(() => _focusedIndex--);
      }
      return;
    }
    if (_focusedIndex == _sectionSettings) {
      setState(() => _focusedIndex = _sectionCalendar);
    } else if (_focusedIndex == _sectionCalendar) {
      setState(() => _focusedIndex = _sectionMovies);
    } else if (_focusedIndex == _sectionMovies) {
      setState(() => _focusedIndex = _sectionTv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const railBg = Colors.transparent;
    final isArcadeInstalled = _arcadePlugin.isInstalled;

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
              _focusedIndex = _toRailIndex(widget.selectedIndex);
            }
          });
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (key == LogicalKeyboardKey.arrowRight) {
            final selected = _toSelectedIndex(_focusedIndex);
            if (selected != widget.selectedIndex) {
              widget.onIndexChanged(selected);
            }
            widget.onFocusRight();
            return KeyEventResult.handled;
          }

          if (key == LogicalKeyboardKey.arrowDown) {
            _moveFocusDown(isArcadeInstalled: isArcadeInstalled);
            return KeyEventResult.handled;
          }

          if (key == LogicalKeyboardKey.arrowUp) {
            _moveFocusUp(isArcadeInstalled: isArcadeInstalled);
            return KeyEventResult.handled;
          }

          if (TvKeyHandler.isActionKey(key)) {
            final selected = _toSelectedIndex(_focusedIndex);
            if (selected != widget.selectedIndex) {
              widget.onIndexChanged(selected);
            }
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: ColoredBox(
          color: railBg,
          child: SizedBox(
            width: 68,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 12),
                _buildRailDestination(_sectionTv, scheme, todayEvents),
                const SizedBox(height: 12),
                _buildRailDestination(_sectionMovies, scheme, todayEvents),
                const SizedBox(height: 12),
                _buildRailDestination(_sectionCalendar, scheme, todayEvents),
                const SizedBox(height: 12),
                if (isArcadeInstalled) ...[
                  _buildRailDestination(_sectionArcade, scheme, todayEvents),
                  const SizedBox(height: 12),
                ],
                const Spacer(),
                const TvVerticalClockPill(),
                const SizedBox(height: 12),
                _buildRailDestination(_sectionSettings, scheme, todayEvents),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestination(int index, ColorScheme scheme, int todayEvents) {
    final bool isSelected = widget.selectedIndex == index;
    final isHovered = _isFocused && _focusedIndex == index;

    final IconData iconData;
    final String label;

    switch (index) {
      case _sectionTv:
        iconData = isSelected ? MoaiIcons.tv : MoaiIcons.tvOutlined;
        label = 'home_rail_tv_title'.tr();
        break;
      case _sectionMovies:
        iconData = isSelected ? MoaiIcons.movie : MoaiIcons.movieOutlined;
        label = 'home_rail_movies_title'.tr();
        break;
      case _sectionCalendar:
        iconData =
            isSelected ? MoaiIcons.calendarMonth : MoaiIcons.calendarMonthOutlined;
        label = 'home_rail_calendar_title'.tr();
        break;
      case _sectionArcade:
        iconData =
            isSelected ? MoaiIcons.sportsEsports : MoaiIcons.sportsEsportsOutlined;
        label = 'home_rail_arcade_title'.tr();
        break;
      case _sectionSettings:
      default:
        iconData = isSelected ? MoaiIcons.settings : MoaiIcons.settingsOutlined;
        label = 'home_rail_settings_title'.tr();
        break;
    }

    final Color pillColor;
    final Color iconColor;
    final Color textColor;

    if (isHovered) {
      pillColor = scheme.primary;
      iconColor = scheme.onPrimary;
      textColor = scheme.primary;
    } else if (isSelected) {
      pillColor = scheme.primaryContainer;
      iconColor = scheme.onPrimaryContainer;
      textColor = scheme.onPrimaryContainer;
    } else {
      pillColor = Colors.transparent;
      iconColor = scheme.onSurfaceVariant;
      textColor = scheme.onSurfaceVariant;
    }

    Widget iconWidget = Icon(
      iconData,
      size: 24,
      color: iconColor,
    );

    if (index == _sectionCalendar && todayEvents > 0) {
      iconWidget = Badge(
        isLabelVisible: true,
        backgroundColor: scheme.tertiaryContainer,
        textColor: scheme.onTertiaryContainer,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
        label: Text('$todayEvents'),
        child: iconWidget,
      );
    }

    return InkWell(
      onTap: () {
        setState(() => _focusedIndex = index);
        widget.onIndexChanged(_toSelectedIndex(index));
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: pillColor,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: iconWidget,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.display(
                context,
                color: textColor,
                fontSize: 11,
                fontWeight: isSelected || isHovered
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
