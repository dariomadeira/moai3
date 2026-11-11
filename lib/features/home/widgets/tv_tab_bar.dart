import 'package:moai3/features/home/tv_tab.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_focus_style.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Barra de pestañas Explorar / Buscar / Marcadores: el rail del home
/// acostado, con texto.
///  - Cápsula de vidrio esmerilado del mismo grosor que el rail (48).
///  - Pestañas de 40 de alto, separadas 5: sin elegir, el círculo de 40 de
///    un destino del rail (sólo ícono).
///  - Elegida: el vidrio blanco del destino elegido del rail, estirado a
///    pastilla con el título.
///  - Foco D-pad: el verde esmeralda de TV del rail, con brillo y halo.
class TvTabBar extends StatelessWidget {
  final TvTab selectedTab;
  final ValueChanged<TvTab> onTabChanged;
  final FocusNode exploreFocusNode;
  final FocusNode searchFocusNode;
  final FocusNode groupsFocusNode;
  final VoidCallback onFocusDown;
  final VoidCallback onFocusLeft;
  final VoidCallback onFocusPlayer;

  /// Altura de cada pestaña (como los destinos del rail).
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
          height: 48,
          borderRadius: 24,
          frosted: true,
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TvTabPill(
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
              _TvTabPill(
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
              _TvTabPill(
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

class _TvTabPill extends StatefulWidget {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final VoidCallback onKeyDown;

  const _TvTabPill({
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
  State<_TvTabPill> createState() => _TvTabPillState();
}

class _TvTabPillState extends State<_TvTabPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    const radius = BorderRadius.all(
      Radius.circular(TvTabBar.indicatorHeight / 2),
    );

    // Mismos estados que los destinos del rail: foco = acento sólido con
    // su texto, elegida = vidrio blanco, resto = nada; sin foco el contenido
    // va casi negro. (El verde de TV queda sólo en el rail.)
    final fg = _focused
        ? scheme.onPrimary
        : TvVerticalNavRail.idleIconColorOf(context);
    final BoxDecoration? decoration;
    if (_focused) {
      decoration = MoaiFocusStyle.decoration(scheme, borderRadius: radius);
    } else if (widget.isSelected) {
      decoration = moaiGlassButtonDecoration(scheme, focused: false);
    } else {
      decoration = null;
    }

    return Semantics(
      label: widget.title,
      button: true,
      selected: widget.isSelected,
      excludeSemantics: true,
      child: Focus(
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
          // Sin elegir: el círculo de 40 de un destino del rail, sólo ícono.
          // Elegida: se estira a pastilla con el título.
          child: Container(
            height: TvTabBar.indicatorHeight,
            constraints: const BoxConstraints(
              minWidth: TvTabBar.indicatorHeight,
            ),
            alignment: Alignment.center,
            padding: widget.isSelected
                ? const EdgeInsets.only(left: 10, right: 14)
                : EdgeInsets.zero,
            decoration: decoration,
            child: Row(
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
      ),
    );
  }
}
