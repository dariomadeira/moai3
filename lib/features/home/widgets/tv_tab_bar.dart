import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';

/// Floating Toolbar M3 Expressive para las pestañas Explorar / Mis grupos.
///
/// Diseño visual:
///  - Cápsula flotante continua con colores planos sin bordes ([ColorScheme.surfaceContainerHigh]).
///  - Pestaña activa expandida con icono y texto ([ColorScheme.secondaryContainer]).
///  - Pestaña inactiva compacta sólo con icono ([ColorScheme.onSurfaceVariant]).
///  - Foco D-Pad de alto contraste con [ColorScheme.primary].
class TvTabBar extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onTabChanged;
  final FocusNode exploreFocusNode;
  final FocusNode searchFocusNode;
  final FocusNode groupsFocusNode;
  final VoidCallback onFocusDown;
  final VoidCallback onFocusLeft;
  final VoidCallback onFocusPlayer;

  /// Altura del indicador interno de cada píldora.
  static const double indicatorHeight = 32;

  const TvTabBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.exploreFocusNode,
    required this.searchFocusNode,
    required this.groupsFocusNode,
    required this.onFocusDown,
    required this.onFocusLeft,
    required this.onFocusPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      // Alineación vertical superior para sincronizar con NavigationRail M3.
      padding: const EdgeInsets.only(top: 12, bottom: 12, right: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _M3EFloatingTabPill(
                title: 'home_tab_explore'.tr(),
                icon: AppIcons.home,
                selectedIcon: AppIcons.home,
                isSelected: selectedTab == 'explore',
                focusNode: exploreFocusNode,
                onSelect: () => onTabChanged('explore'),
                onKeyLeft: onFocusLeft,
                onKeyRight: () => searchFocusNode.requestFocus(),
                onKeyDown: onFocusDown,
              ),
              const SizedBox(width: 4),
              _M3EFloatingTabPill(
                title: 'home_tab_search'.tr(),
                icon: AppIcons.search,
                selectedIcon: AppIcons.search,
                isSelected: selectedTab == 'search',
                focusNode: searchFocusNode,
                onSelect: () => onTabChanged('search'),
                onKeyLeft: () => exploreFocusNode.requestFocus(),
                onKeyRight: () => groupsFocusNode.requestFocus(),
                onKeyDown: onFocusDown,
              ),
              const SizedBox(width: 4),
              _M3EFloatingTabPill(
                title: 'home_tab_groups'.tr(),
                icon: AppIcons.group,
                selectedIcon: AppIcons.group,
                isSelected: selectedTab == 'groups',
                focusNode: groupsFocusNode,
                onSelect: () => onTabChanged('groups'),
                onKeyLeft: () => searchFocusNode.requestFocus(),
                onKeyRight: onFocusPlayer,
                onKeyDown: onFocusDown,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _M3EFloatingTabPill extends StatefulWidget {
  final String title;
  final dynamic icon;
  final dynamic selectedIcon;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final VoidCallback onKeyDown;

  const _M3EFloatingTabPill({
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.focusNode,
    required this.onSelect,
    required this.onKeyLeft,
    required this.onKeyRight,
    required this.onKeyDown,
  });

  @override
  State<_M3EFloatingTabPill> createState() => _M3EFloatingTabPillState();
}

class _M3EFloatingTabPillState extends State<_M3EFloatingTabPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final Color bg;
    final Color fg;

    // Sincronizado exactamente con los tokens visuales del NavigationRail.
    if (_focused) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (widget.isSelected) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = Colors.transparent;
      fg = scheme.onSurfaceVariant;
    }

    final currentIcon = widget.isSelected ? widget.selectedIcon : widget.icon;

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
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          widget.focusNode.requestFocus();
          widget.onSelect();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          clipBehavior: Clip.antiAlias,
          height: TvTabBar.indicatorHeight,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 12 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon: currentIcon,
                color: fg,
                size: 18,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: widget.isSelected
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 6),
                          Text(
                            widget.title,
                            maxLines: 1,
                            softWrap: false,
                            style: MoaiText.display(
                              context,
                              color: fg,
                              fontSize: 12,
                              fontWeight: widget.isSelected || _focused
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

