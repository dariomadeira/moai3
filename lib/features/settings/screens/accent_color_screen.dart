import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
enum _AccentScreenItemType {
  colorDotsSelector,
  autoAccentSwitch,
}

/// Pantalla de configuración de color de acento.
/// Contiene un listado tipo ventana (máx. 6 ítems, como en el resto de Ajustes)
/// con el selector interactivo de color y el switch de color automático.
class AccentColorScreen extends StatefulWidget {
  const AccentColorScreen({super.key});

  @override
  State<AccentColorScreen> createState() => _AccentColorScreenState();
}

class _AccentColorScreenState extends State<AccentColorScreen> {
  static const int _windowSize = 6;
  static const double _itemExtent = 70.0;

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
    final scheme = context.scheme;
    final theme = context.watch<ThemeProvider>();
    final selectedIndex = theme.accentColorIndex;
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.brightness == Brightness.dark
                ? [
                    Color.lerp(
                      scheme.surfaceContainerHigh,
                      scheme.primary,
                      0.08,
                    )!,
                    scheme.surfaceContainerLow,
                  ]
                : [scheme.surfaceContainerLowest, scheme.surfaceContainerHigh],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/fondo.png',
                  fit: BoxFit.cover,
                ),
              ),
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
                          colors: [scheme.surface.withValues(alpha: 0.8)],
                          titles: ['settings_general_accent'.tr()],
                          icons: const [MoaiIcons.paletteOutlined],
                          onPanelTap: (_) {},
                          tabBuilder: (index, isExpanded) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 14,
                                top: 14,
                              ),
                              child: Column(
                                children: [
                                  const Spacer(),
                                  RotatedBox(
                                    quarterTurns: 3,
                                    child: Text(
                                      'settings_general_accent'.tr(),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      style: MoaiText.display(
                                        context,
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Icon(
                                    MoaiIcons.paletteOutlined,
                                    size: 20,
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          buildExpandedContent: (index, title) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TvPanelHeader(
                                    title: 'settings_general_accent'.tr(),
                                    subtitle:
                                        'settings_general_accent_desc'.tr(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 14),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final targetHeight =
                                            (_windowSize * _itemExtent).clamp(
                                          0.0,
                                          constraints.maxHeight,
                                        );
                                        return Align(
                                          alignment: Alignment.bottomCenter,
                                          child: SizedBox(
                                            height: targetHeight,
                                            child: Align(
                                              alignment: Alignment.topCenter,
                                              child: TvWindowedList<
                                                  _AccentScreenItemType>(
                                                key: _listKey,
                                                items: items,
                                                itemExtent: _itemExtent,
                                                showScrollDots: true,
                                                initialGlobalIndex:
                                                    _selectedItemIndex,
                                                onFocusedGlobalIndex: (idx) {
                                                  _selectedItemIndex = idx;
                                                },
                                                onFocusUpFromFirst: _backFocusNode.requestFocus,
                                                itemBuilder: (
                                                  context,
                                                  item,
                                                  focusNode,
                                                  local,
                                                  global,
                                                  onKeyUp,
                                                  onKeyDown,
                                                ) {
                                                  switch (item) {
                                                    case _AccentScreenItemType
                                                          .colorDotsSelector:
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 3,
                                                        ),
                                                        child:
                                                            _AccentColorSelectorTile(
                                                          focusNode: focusNode,
                                                          selectedIndex:
                                                              selectedIndex,
                                                          onChanged: theme.setAccentColorIndex,
                                                          onKeyLeft: _backFocusNode.requestFocus,
                                                          onKeyUp: onKeyUp,
                                                          onKeyDown: onKeyDown,
                                                        ),
                                                      );
                                                    case _AccentScreenItemType
                                                          .autoAccentSwitch:
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          vertical: 3,
                                                        ),
                                                        child:
                                                            TvSettingsSwitchRow(
                                                          focusNode: focusNode,
                                                          icon: MoaiIcons
                                                              .autoAwesomeOutlined,
                                                          label:
                                                              'settings_general_auto_accent'
                                                                  .tr(),
                                                          description:
                                                              'settings_general_auto_accent_desc'
                                                                  .tr(),
                                                          value: isAutoAccent,
                                                          onChanged: theme.setAutoAccent,
                                                          onKeyLeft: _backFocusNode.requestFocus,
                                                          onKeyUp: onKeyUp,
                                                          onKeyDown: onKeyDown,
                                                        ),
                                                      );
                                                  }
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
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila estilo TvTile que contiene los dots de colores como en el selector original,
/// navegable con Left/Right en el D-pad sin sombras y con borde máx 2px.
class _AccentColorSelectorTile extends StatelessWidget {
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

  void _select(int index) {
    final next = MoaiAccentColors.clampIndex(index);
    if (next != selectedIndex) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorName = selectedIndex >= 0 &&
            selectedIndex < MoaiAccentColors.labelKeys.length
        ? MoaiAccentColors.labelKeys[selectedIndex].tr()
        : '';

    return TvTile(
      focusNode: focusNode,
      label: 'settings_general_accent'.tr(),
      description: colorName.isNotEmpty
          ? '$colorName · ${'settings_general_accent_desc'.tr()}'
          : 'settings_general_accent_desc'.tr(),
      icon: MoaiIcons.paletteOutlined,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.arrowUp) {
          onKeyUp();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          onKeyDown();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (selectedIndex > 0) {
            _select(selectedIndex - 1);
          } else {
            onKeyLeft();
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (selectedIndex < MoaiAccentColors.seeds.length - 1) {
            _select(selectedIndex + 1);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      trailingBuilder: (context, isFocused) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            MoaiAccentColors.seeds.length,
            (i) {
              final isSelected = i == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: isSelected ? 22 : 16,
                  height: isSelected ? 22 : 16,
                  decoration: BoxDecoration(
                    color: MoaiAccentColors.seeds[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.transparent,
                      width: isSelected ? 2.0 : 0.0,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Icon(
                            MoaiIcons.checkOutlined,
                            size: 11,
                            color: ThemeData.estimateBrightnessForColor(
                                        MoaiAccentColors.seeds[i]) ==
                                    Brightness.dark
                                ? Colors.white
                                : Colors.black,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
