import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:moai3/features/home/widgets/tv_vertical_clock_pill.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

/// Rail lateral de navegación para Android TV: TV, Calendario, Arcade (si está instalado) y Ajustes.
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

          // → : sincronizar sección o entrar al panel de contenido.
          if (key == LogicalKeyboardKey.arrowRight) {
            final selected = _toSelectedIndex(_focusedIndex);
            if (selected != widget.selectedIndex) {
              widget.onIndexChanged(selected);
            }
            widget.onFocusRight();
            return KeyEventResult.handled;
          }

          // ↓ : bajar en el rail
          if (key == LogicalKeyboardKey.arrowDown) {
            if (isArcadeInstalled) {
              if (_focusedIndex < 3) setState(() => _focusedIndex++);
            } else {
              if (_focusedIndex == 0) {
                setState(() => _focusedIndex = 1);
              } else if (_focusedIndex == 1) {
                setState(() => _focusedIndex = 3);
              }
            }
            return KeyEventResult.handled;
          }

          // ↑ : subir en el rail
          if (key == LogicalKeyboardKey.arrowUp) {
            if (isArcadeInstalled) {
              if (_focusedIndex > 0) setState(() => _focusedIndex--);
            } else {
              if (_focusedIndex == 3) {
                setState(() => _focusedIndex = 1);
              } else if (_focusedIndex == 1) {
                setState(() => _focusedIndex = 0);
              }
            }
            return KeyEventResult.handled;
          }

          // OK / Enter: seleccionar sección
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
                // Destino 0: TV
                _buildRailDestination(0, scheme, todayEvents),
                const SizedBox(height: 12),
                // Destino 1: Calendario
                _buildRailDestination(1, scheme, todayEvents),
                const SizedBox(height: 12),
                // Destino 2: Arcade (solo si el plugin está instalado)
                if (isArcadeInstalled) ...[
                  _buildRailDestination(2, scheme, todayEvents),
                  const SizedBox(height: 12),
                ],

                // Espaciador flexible que posiciona Ajustes al final de la pantalla
                const Spacer(),

                // Reloj cápsula vertical sobre Ajustes
                const TvVerticalClockPill(),
                const SizedBox(height: 12),

                // Destino 3: Ajustes (al fondo)
                _buildRailDestination(3, scheme, todayEvents),
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

    final String label;
    final List<List<dynamic>> hugeIconData;

    switch (index) {
      case 0:
        hugeIconData = HugeIcons.strokeRoundedModernTv;
        label = 'home_rail_tv_title'.tr();
        break;
      case 1:
        hugeIconData = HugeIcons.strokeRoundedCalendar03;
        label = 'home_rail_calendar_title'.tr();
        break;
      case 2:
        hugeIconData = HugeIcons.strokeRoundedGameController03;
        label = 'home_rail_arcade_title'.tr();
        break;
      case 3:
      default:
        hugeIconData = HugeIcons.strokeRoundedSettings01;
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

    Widget iconWidget = HugeIcon(
      icon: hugeIconData,
      color: iconColor,
      size: 22,
    );

    if (index == 1 && todayEvents > 0) {
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
