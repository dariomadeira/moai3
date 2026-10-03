import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

/// Rail lateral de navegación para Android TV: TV, Calendario y Ajustes (al pie).
///
/// Soporta íconos outlined por defecto y rellenos (filled) al estar seleccionados.
/// Ajustes queda fijado abajo del todo con navegación D-Pad 100% fluida y predecible.
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

  @override
  void initState() {
    super.initState();
    _focusedIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant NavigationRailSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFocused) {
      _focusedIndex = widget.selectedIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const railBg = Colors.transparent;

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
              _focusedIndex = widget.selectedIndex;
            }
          });
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          // → : sincronizar sección y entrar al panel de contenido.
          if (key == LogicalKeyboardKey.arrowRight) {
            if (_focusedIndex != widget.selectedIndex) {
              widget.onIndexChanged(_focusedIndex);
            }
            widget.onFocusRight();
            return KeyEventResult.handled;
          }

          // ↓ : bajar en el rail (TV 0 -> Películas 1 -> Calendario 2 -> Ajustes 3)
          if (key == LogicalKeyboardKey.arrowDown) {
            if (_focusedIndex < 3) {
              setState(() => _focusedIndex++);
            }
            return KeyEventResult.handled;
          }

          // ↑ : subir en el rail (Ajustes 3 -> Calendario 2 -> Películas 1 -> TV 0)
          if (key == LogicalKeyboardKey.arrowUp) {
            if (_focusedIndex > 0) {
              setState(() => _focusedIndex--);
            }
            return KeyEventResult.handled;
          }

          if (TvKeyHandler.isActionKey(key)) {
            if (_focusedIndex != widget.selectedIndex) {
              widget.onIndexChanged(_focusedIndex);
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
                // Destino 1: Películas
                _buildRailDestination(1, scheme, todayEvents),
                const SizedBox(height: 12),
                // Destino 2: Calendario
                _buildRailDestination(2, scheme, todayEvents),

                // Espaciador flexible que posiciona Ajustes al final de la pantalla
                const Spacer(),

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
    final isSelected = widget.selectedIndex == index;
    final isHovered = _isFocused && _focusedIndex == index;

    final IconData iconData;
    final String label;

    switch (index) {
      case 0:
        iconData = isSelected ? Icons.tv : Icons.tv_outlined;
        label = 'home_rail_tv_title'.tr();
        break;
      case 1:
        iconData = isSelected ? Icons.movie : Icons.movie_outlined;
        label = 'home_rail_movies_title'.tr();
        break;
      case 2:
        iconData =
            isSelected ? Icons.calendar_month : Icons.calendar_month_outlined;
        label = 'home_rail_calendar_title'.tr();
        break;
      case 3:
      default:
        iconData = isSelected ? Icons.settings : Icons.settings_outlined;
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

    if (index == 2 && todayEvents > 0) {
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
        widget.onIndexChanged(index);
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
