import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Barra flotante de pestañas Explorar / Buscar / Marcadores, hermana del
/// rail del home:
///  - Cápsula de cristal del mismo grosor que el rail (48).
///  - Pestaña activa expandida con ícono y texto, en cristal teñido del acento.
///  - Pestaña inactiva compacta, sólo ícono.
///  - Foco D-pad: acento sólido con brillo arriba y halo.
class TvTabBar extends StatelessWidget {
  final TvTab selectedTab;
  final ValueChanged<TvTab> onTabChanged;
  final FocusNode exploreFocusNode;
  final FocusNode searchFocusNode;
  final FocusNode groupsFocusNode;
  final VoidCallback onFocusDown;
  final VoidCallback onFocusLeft;
  final VoidCallback onFocusPlayer;

  /// Altura de cada píldora (como los íconos del rail).
  static const double indicatorHeight = 40;

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
    return Padding(
      // Alineación vertical superior para sincronizar con NavigationRail M3.
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: MoaiGlass(
          borderRadius: 24,
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _M3EFloatingTabPill(
                title: LocaleKeys.home_tab_explore.tr(),
                icon: MoaiIcons.tvTabExplorar,
                selectedIcon: MoaiIcons.tvTabExplorarSelected,
                isSelected: selectedTab == TvTab.explore,
                focusNode: exploreFocusNode,
                onSelect: () => onTabChanged(TvTab.explore),
                onKeyLeft: onFocusLeft,
                onKeyRight: searchFocusNode.requestFocus,
                onKeyDown: onFocusDown,
              ),
              const SizedBox(width: 5),
              _M3EFloatingTabPill(
                title: LocaleKeys.home_tab_search.tr(),
                icon: MoaiIcons.tvTabBuscar,
                selectedIcon: MoaiIcons.tvTabBuscarSelected,
                isSelected: selectedTab == TvTab.search,
                focusNode: searchFocusNode,
                onSelect: () => onTabChanged(TvTab.search),
                onKeyLeft: exploreFocusNode.requestFocus,
                onKeyRight: groupsFocusNode.requestFocus,
                onKeyDown: onFocusDown,
              ),
              const SizedBox(width: 5),
              _M3EFloatingTabPill(
                title: LocaleKeys.home_tab_groups.tr(),
                icon: MoaiIcons.tvTabMarcadores,
                selectedIcon: MoaiIcons.tvTabMarcadoresSelected,
                isSelected: selectedTab == TvTab.groups,
                focusNode: groupsFocusNode,
                onSelect: () => onTabChanged(TvTab.groups),
                onKeyLeft: searchFocusNode.requestFocus,
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
  final IconData icon;
  final IconData selectedIcon;
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

    // Mismos estados que el rail: foco = acento sólido, activa = cristal
    // teñido, resto = sólo ícono.
    final Color fg;
    if (_focused) {
      fg = scheme.onPrimary;
    } else if (widget.isSelected) {
      fg = scheme.onSurface;
    } else {
      fg = scheme.onSurfaceVariant;
    }
    const radius = TvTabBar.indicatorHeight / 2;
    final padding = EdgeInsets.symmetric(
      horizontal: widget.isSelected ? 14 : 10,
    );

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
        child: _buildFrame(
          scheme,
          radius,
          padding,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSelected ? widget.selectedIcon : widget.icon,
                color: fg,
                size: MoaiIconSizes.md,
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

  Widget _buildFrame(
    ColorScheme scheme,
    double radius,
    EdgeInsets padding,
    Widget content,
  ) {
    if (_focused) {
      return Container(
        height: TvTabBar.indicatorHeight,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
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
        child: content,
      );
    }
    if (widget.isSelected) {
      return MoaiGlass(
        height: TvTabBar.indicatorHeight,
        borderRadius: radius,
        tint: scheme.primary,
        elevated: false,
        padding: padding,
        child: content,
      );
    }
    return Container(
      height: TvTabBar.indicatorHeight,
      padding: padding,
      child: content,
    );
  }
}
