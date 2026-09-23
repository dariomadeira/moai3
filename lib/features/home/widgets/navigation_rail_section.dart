import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

/// Rail lateral (paridad moaiSmart 100%): TV + Ajustes.
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
    final railBg = scheme.surfaceContainer;

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

          // ↓ : bajar en el rail (consumir siempre para no saltar de scope)
          if (key == LogicalKeyboardKey.arrowDown) {
            if (_focusedIndex < 2) {
              setState(() => _focusedIndex++);
            }
            return KeyEventResult.handled;
          }

          // ↑ : subir en el rail (consumir siempre para no saltar de scope)
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
          child: ExcludeFocus(
            child: Builder(
              builder: (context) {
                final todayEvents = context.select(
                  (CalendarProvider p) => p.todayEventCount,
                );

                return NavigationRail(
                  minWidth: 56,
                  backgroundColor: railBg,
                  selectedIndex: _isFocused ? _focusedIndex : widget.selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _focusedIndex = index);
                    widget.onIndexChanged(index);
                  },
                  labelType: NavigationRailLabelType.all,
                  useIndicator: true,
                  indicatorColor:
                      _isFocused ? scheme.primary : scheme.primaryContainer,
                  selectedIconTheme: IconThemeData(
                    color:
                        _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer,
                    size: 26,
                  ),
                  unselectedIconTheme: IconThemeData(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    size: 26,
                  ),
                  selectedLabelTextStyle: MoaiText.display(
                    context,
                    color:
                        _isFocused ? scheme.primary : scheme.onPrimaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelTextStyle: MoaiText.display(
                    context,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.tv_outlined),
                      selectedIcon: const Icon(Icons.tv),
                      label: Text('home_rail_tv_title'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: Badge(
                        isLabelVisible: todayEvents > 0,
                        backgroundColor: scheme.tertiaryContainer,
                        textColor: scheme.onTertiaryContainer,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                        label: Text('$todayEvents'),
                        child: const Icon(Icons.calendar_month_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: todayEvents > 0,
                        backgroundColor: scheme.tertiaryContainer,
                        textColor: scheme.onTertiaryContainer,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                        label: Text('$todayEvents'),
                        child: const Icon(Icons.calendar_month),
                      ),
                      label: Text('home_rail_calendar_title'.tr()),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text('home_rail_settings_title'.tr()),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

