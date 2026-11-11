import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';

enum _AccentScreenItemType { colorDotsSelector, autoAccentSwitch }

/// Pantalla del color de acento. Mismo armado que Plugins (botón volver y un
/// panel del acordeón) y el mismo cuerpo que los paneles de Ajustes
/// ([TvPanelSlots]): encabezado y fichas en los 6 lugares.
class AccentColorScreen extends StatefulWidget {
  const AccentColorScreen({super.key});

  @override
  State<AccentColorScreen> createState() => _AccentColorScreenState();
}

class _AccentColorScreenState extends State<AccentColorScreen> {
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'accent_color_back');
  final GlobalKey<TvWindowedListState<_AccentScreenItemType>> _listKey =
      GlobalKey<TvWindowedListState<_AccentScreenItemType>>();

  int _selectedItemIndex = 0;

  @override
  void dispose() {
    _backFocusNode.dispose();
    super.dispose();
  }

  void _focusList() {
    _listKey.currentState?.ensureVisible(_selectedItemIndex);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isAutoAccent = theme.autoAccent;

    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );

    final items = <_AccentScreenItemType>[
      if (!isAutoAccent) _AccentScreenItemType.colorDotsSelector,
      _AccentScreenItemType.autoAccentSwitch,
    ];

    if (_selectedItemIndex >= items.length) {
      _selectedItemIndex = items.length - 1;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        TvBackPill(
                          focusNode: _backFocusNode,
                          onKeyRight: _focusList,
                          onKeyDown: _focusList,
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: TvAccordionRowPreview(
                        panelCount: 1,
                        activeIndex: 0,
                        titles: [LocaleKeys.settings_general_accent.tr()],
                        icons: const [MoaiIcons.palette],
                        onPanelTap: (_) {},
                        fixedContentWidth: true,
                        buildExpandedContent: (index, title) =>
                            _buildPanel(context, theme, items),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// El cuerpo de un panel de Ajustes (como [SettingsGeneralPanel]).
  Widget _buildPanel(
    BuildContext context,
    ThemeProvider theme,
    List<_AccentScreenItemType> items,
  ) {
    return Container(
      padding: TvPanelSlots.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: LocaleKeys.settings_general_accent.tr(),
            subtitle: LocaleKeys.settings_general_accent_desc.tr(),
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemExtent = TvPanelSlots.extentFor(
                  constraints.maxHeight,
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    height: (TvPanelSlots.count * itemExtent).clamp(
                      0.0,
                      constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: TvWindowedList<_AccentScreenItemType>(
                        key: _listKey,
                        items: items,
                        itemExtent: itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedItemIndex,
                        onFocusedGlobalIndex: (idx) => _selectedItemIndex = idx,
                        onFocusUpFromFirst: _backFocusNode.requestFocus,
                        itemBuilder:
                            (
                              context,
                              item,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                            ) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: TvPanelSlots.gap / 2,
                                ),
                                child: _buildItem(
                                  item: item,
                                  theme: theme,
                                  focusNode: focusNode,
                                  onKeyUp: onKeyUp,
                                  onKeyDown: onKeyDown,
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required _AccentScreenItemType item,
    required ThemeProvider theme,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _AccentScreenItemType.colorDotsSelector:
        return _AccentColorSelectorTile(
          focusNode: focusNode,
          selectedIndex: theme.accentColorIndex,
          onChanged: theme.setAccentColorIndex,
          onKeyLeft: _backFocusNode.requestFocus,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _AccentScreenItemType.autoAccentSwitch:
        return TvSettingsSwitchRow(
          focusNode: focusNode,
          icon: MoaiIcons.autoAccent,
          label: LocaleKeys.settings_general_auto_accent.tr(),
          description: LocaleKeys.settings_general_auto_accent_desc.tr(),
          value: theme.autoAccent,
          onChanged: theme.setAutoAccent,
          onKeyLeft: _backFocusNode.requestFocus,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
    }
  }
}

/// Ficha de Ajustes con los colores a la derecha. Como [SettingsOptionRow]:
/// sin editar, ←/→ se mueven como en cualquier fila; OK entra a elegir
/// (aparecen las flechas), ←/→ cambian el color y OK o Atrás salen; ↑/↓
/// salen y se mueven.
class _AccentColorSelectorTile extends StatefulWidget {
  final FocusNode focusNode;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  const _AccentColorSelectorTile({
    required this.focusNode,
    required this.selectedIndex,
    required this.onChanged,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
  });

  @override
  State<_AccentColorSelectorTile> createState() =>
      _AccentColorSelectorTileState();
}

class _AccentColorSelectorTileState extends State<_AccentColorSelectorTile> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _AccentColorSelectorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _setEditing(bool value) {
    if (_editing != value) setState(() => _editing = value);
  }

  void _step(int delta) {
    final next = widget.selectedIndex + delta;
    if (next < 0 || next >= MoaiAccentColors.seeds.length) return;
    widget.onChanged(next);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_editing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (TvKeyHandler.isActionKey(key) ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      _setEditing(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      // Sale de elegir y deja que la fila mueva el foco.
      _setEditing(false);
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final selectedIndex = widget.selectedIndex;
    final colorName =
        selectedIndex >= 0 && selectedIndex < MoaiAccentColors.labelKeys.length
        ? MoaiAccentColors.labelKeys[selectedIndex].tr()
        : '';
    final editing = _editing && widget.focusNode.hasFocus;

    return TvTile(
      focusNode: widget.focusNode,
      label: LocaleKeys.settings_general_accent.tr(),
      description: colorName,
      icon: MoaiIcons.palette,
      onPressed: () => _setEditing(true),
      onKeyLeft: widget.onKeyLeft,
      onKeyUp: widget.onKeyUp,
      onKeyDown: widget.onKeyDown,
      onKeyEvent: _onKeyEvent,
      trailingBuilder: (context, isFocused) {
        final dots = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(MoaiAccentColors.seeds.length, (i) {
            final isSelected = i == selectedIndex;
            final color = MoaiAccentColors.seeds[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: isSelected ? 22 : 16,
                height: isSelected ? 22 : 16,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  // Sobre el cristal claro un aro blanco no se ve: va en el
                  // color del texto.
                  border: isSelected
                      ? Border.all(color: scheme.onSurface, width: 2)
                      : null,
                ),
                child: isSelected
                    ? Center(
                        child: Icon(
                          MoaiIcons.colorSelected,
                          size: MoaiIconSizes.xs,
                          color:
                              ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black,
                        ),
                      )
                    : null,
              ),
            );
          }),
        );
        if (!editing) return dots;
        // Eligiendo: las flechas a los lados, como [TvOptionSelector].
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.chevronLeft,
              size: MoaiIconSizes.sm,
              color: scheme.primary,
            ),
            const SizedBox(width: 4),
            dots,
            const SizedBox(width: 4),
            Icon(
              MoaiIcons.chevronRight,
              size: MoaiIconSizes.sm,
              color: scheme.primary,
            ),
          ],
        );
      },
    );
  }
}
