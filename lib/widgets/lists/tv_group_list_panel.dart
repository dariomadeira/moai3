import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';

/// Panel de una lista de grupos de canales (Países, Categorías, Marcadores):
/// encabezado con degradado, fichas que llenan el alto y los estados del
/// rail en el acento. Cada panel dice qué lista, qué textos y cómo es su
/// ficha; el foco, la ventana y el estado vacío son de acá.
abstract class TvGroupListPanel<T> extends StatefulWidget {
  const TvGroupListPanel({super.key, this.onFocusUp});

  final VoidCallback? onFocusUp;

  List<T> get items;

  /// Índice del elegido en [items]; -1 si no hay.
  int get selectedIndex;

  /// Si la selección cambió respecto de [old] (para volver a mostrarla).
  bool selectionChanged(covariant TvGroupListPanel<T> old);

  String get title;

  /// Con un solo ítem; con más, la pista de buscar con filtro.
  String get subtitle;

  IconData get emptyIcon;
  String get emptyMessage;
  String get debugName;

  /// Si la lista toma el foco al montarse.
  bool get focusOnMount => true;

  /// La ficha de [item], ya con su foco y sus flechas.
  Widget buildTile(
    BuildContext context,
    T item,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  );

  @override
  State<TvGroupListPanel<T>> createState() => TvGroupListPanelState<T>();
}

class TvGroupListPanelState<T> extends State<TvGroupListPanel<T>>
    implements FocusSelectable {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final _listKey = GlobalKey<TvWindowedListState<T>>();
  late final FocusNode _emptyFocusNode = FocusNode(
    debugLabel: '${widget.debugName}_empty',
  );
  int? _focusedIndex;

  /// Alto mínimo de cada lugar: ficha de 48 más la separación.
  static const double _minItemExtent = 48 + TvPanelSlots.gap;

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    super.dispose();
  }

  int get _selectedIndex {
    if (_focusedIndex != null && _focusedIndex! < widget.items.length) {
      return _focusedIndex!;
    }
    final idx = widget.selectedIndex;
    return idx >= 0 ? idx : 0;
  }

  /// Lo llama HomeTvArea (rail → / ← desde el panel de al lado / alfabeto /
  /// returnFocus).
  @override
  void focusSelected() => focusGlobalIndex(_selectedIndex);

  void focusGlobalIndex(int index) {
    if (widget.items.isEmpty) {
      _focus.node(_emptyFocusNode);
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  @override
  void didUpdateWidget(covariant TvGroupListPanel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectionChanged(oldWidget)) return;
    _focusedIndex = null;
    if (widget.items.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listKey.currentState?.ensureVisible(_selectedIndex, requestFocus: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Container(
      padding: TvPanelSlots.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: widget.title,
            subtitle: items.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : widget.subtitle,
            titleShader: HomeClock.timeShader,
          ),
          TvPanelSlots.belowHeader,
          Expanded(
            child: items.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: TvEmptyStateCard(
                      focusNode: _emptyFocusNode,
                      icon: widget.emptyIcon,
                      message: widget.emptyMessage,
                      onFocusUp: widget.onFocusUp,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Entran tantas fichas como quepan enteras y se
                      // estiran para llenar el alto: nunca quedan cortadas
                      // ni con hueco abajo.
                      final height = constraints.maxHeight;
                      final windowSize = (height / _minItemExtent)
                          .floor()
                          .clamp(1, 64);
                      return TvWindowedList<T>(
                        key: _listKey,
                        items: items,
                        windowSize: windowSize,
                        itemExtent: height / windowSize,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        focusOnMount: widget.focusOnMount,
                        onFocusUpFromFirst: widget.onFocusUp,
                        onFocusedGlobalIndex: (idx) => _focusedIndex = idx,
                        itemBuilder:
                            (
                              context,
                              item,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                            ) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: TvPanelSlots.gap / 2,
                              ),
                              child: widget.buildTile(
                                context,
                                item,
                                focusNode,
                                onKeyUp,
                                onKeyDown,
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
}
