import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tabs Explorar / Grupos.
///
/// Alineación: `top: 8` = `_verticalSpacer` interno del [NavigationRail] M3,
/// para que el pill quede a la misma altura que el indicador TV.
/// Colores: misma lógica que [NavigationRailSection].
class TvTabBar extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final FocusNode exploreFocusNode;
  final FocusNode groupsFocusNode;
  final VoidCallback onFocusDown;
  final VoidCallback onFocusLeft;
  final VoidCallback onFocusPlayer;

  /// Altura del indicador M3 del NavigationRail.
  static const double indicatorHeight = 32;

  const TvTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.exploreFocusNode,
    required this.groupsFocusNode,
    required this.onFocusDown,
    required this.onFocusLeft,
    required this.onFocusPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 8 = spacer vertical del NavigationRail (Material).
      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabPill(
              title: 'home_tab_explore'.tr(),
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore,
              isSelected: selectedTab == 'explore',
              focusNode: exploreFocusNode,
              onFocused: () => onTabChanged('explore'),
              onKeyLeft: onFocusLeft,
              onKeyRight: () => groupsFocusNode.requestFocus(),
              onKeyDown: onFocusDown,
            ),
            const SizedBox(width: 12),
            _TabPill(
              title: 'home_tab_groups'.tr(),
              icon: Symbols.stack,
              selectedIcon: Symbols.stack,
              isSelected: selectedTab == 'groups',
              focusNode: groupsFocusNode,
              onFocused: () => onTabChanged('groups'),
              onKeyLeft: () => exploreFocusNode.requestFocus(),
              onKeyRight: onFocusPlayer,
              onKeyDown: onFocusDown,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPill extends StatefulWidget {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final VoidCallback onKeyDown;

  const _TabPill({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.focusNode,
    required this.onFocused,
    required this.onKeyLeft,
    required this.onKeyRight,
    required this.onKeyDown,
  });

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final Color bg;
    final Color fg;
    if (_focused) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (widget.isSelected) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = Colors.transparent;
      fg = scheme.onSurface.withValues(alpha: 0.6);
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          widget.onKeyRight();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          widget.onKeyDown();
          return KeyEventResult.handled;
        }
        if (TvKeyHandler.isActionKey(key)) {
          widget.onFocused();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onFocused();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: TvTabBar.indicatorHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            // Mismo radio que el indicador del NavigationRail M3.
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected || _focused
                    ? widget.selectedIcon
                    : widget.icon,
                color: fg,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: MoaiText.display(
                  context,
                  color: fg,
                  fontSize: 12,
                  fontWeight: widget.isSelected || _focused
                      ? FontWeight.w700
                      : FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

