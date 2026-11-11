import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/voice_search_service.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_grid.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_focus_ring.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_panel_slots.dart';

/// Panel Buscar: el encabezado de Grupos y Canales (título en dos colores y
/// la ayuda), el campo de búsqueda y la grilla de canales de 3 columnas que
/// llena el alto.
class SearchPanel extends StatefulWidget {
  final String title;
  final TextEditingController queryController;
  final FocusNode searchFocusNode;
  final FocusNode clearFocusNode;
  final List<Channel> searchResults;
  final bool showSearchPrompt;
  final bool resultsCapped;
  final Channel? selectedChannel;
  final VoidCallback onFocusUp;

  /// Id del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedChannelId;
  final VoidCallback onLongPress;
  final ValueChanged<Channel> onSelectChannel;

  const SearchPanel({
    super.key,
    required this.title,
    required this.queryController,
    required this.searchFocusNode,
    required this.clearFocusNode,
    required this.searchResults,
    required this.showSearchPrompt,
    required this.resultsCapped,
    required this.selectedChannel,
    required this.onFocusUp,
    this.tunedChannelId,
    required this.onLongPress,
    required this.onSelectChannel,
  });

  @override
  State<SearchPanel> createState() => SearchPanelState();
}

class SearchPanelState extends State<SearchPanel> implements FocusSelectable {
  static const int _crossAxisCount = 3;

  /// Alto mínimo de cada fila: la ficha de canal más la separación.
  static const double _minRowExtent = 96 + ChannelGridTile.gap;

  final _listKey = GlobalKey<TvWindowedGridState<Channel>>();
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'search_empty');
  final FocusNode _micFocusNode = FocusNode(debugLabel: 'search_mic');

  @override
  void dispose() {
    _emptyFocusNode.dispose();
    _micFocusNode.dispose();
    super.dispose();
  }

  /// OK en el micrófono (como en Películas): lo dictado queda escrito y la
  /// búsqueda corre sola al cambiar el texto.
  Future<void> _dictate() async {
    final String? text;
    try {
      text = await VoiceSearchService.listen();
    } on PlatformException {
      if (mounted) {
        MoaiSnackBar.show(
          context,
          message: LocaleKeys.movies_search_voice_unavailable.tr(),
          icon: MoaiIcons.mic,
        );
      }
      return;
    }
    final query = text?.trim() ?? '';
    if (!mounted || query.isEmpty) return;
    widget.queryController.text = query;
    widget.searchFocusNode.requestFocus();
  }

  int get _selectedIndex {
    final id = widget.selectedChannel?.id;
    if (id == null) return 0;
    final idx = widget.searchResults.indexWhere((c) => c.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

  @override
  void focusSelected() {
    if (widget.searchResults.isEmpty) {
      _focusInputFromFirstResult();
      return;
    }
    _listKey.currentState?.ensureVisible(_selectedIndex);
  }

  void focusFirst() {
    if (widget.searchResults.isEmpty) {
      _focusInputFromFirstResult();
      return;
    }
    _listKey.currentState?.ensureVisible(0);
  }

  void focusGlobalIndex(int index) {
    if (widget.searchResults.isEmpty) {
      _focusInputFromFirstResult();
      return;
    }
    _listKey.currentState?.ensureVisible(index);
  }

  /// ↓ desde el campo: a la grilla o, sin resultados, al estado vacío.
  void _focusResultsFromInput() {
    if (widget.searchResults.isEmpty) {
      _emptyFocusNode.requestFocus();
      return;
    }
    focusSelected();
  }

  void _focusInputFromFirstResult() {
    if (widget.queryController.text.isNotEmpty) {
      widget.clearFocusNode.requestFocus();
    } else {
      widget.searchFocusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant SearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selChanged =
        oldWidget.selectedChannel?.id != widget.selectedChannel?.id;
    final listChanged =
        !identical(oldWidget.searchResults, widget.searchResults) ||
        oldWidget.searchResults.length != widget.searchResults.length;
    if ((selChanged || listChanged) && widget.searchResults.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _listKey.currentState?.ensureVisible(
          _selectedIndex,
          requestFocus: false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = widget.queryController.text.isNotEmpty;
    final capped = widget.resultsCapped && !widget.showSearchPrompt;

    return Container(
      // Sin pestaña vertical a la izquierda (como Grupos o Canales): el
      // margen izquierdo es igual al de abajo (8 + la media separación que
      // la última fila trae debajo).
      padding: TvPanelSlots.panelPadding.copyWith(
        left: TvPanelSlots.panelPadding.bottom + ChannelGridTile.gap / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvPanelHeader(
            title: widget.title,
            subtitle: capped
                ? LocaleKeys.search_results_capped.tr()
                : widget.searchResults.length > 1
                ? LocaleKeys.search_hint_with_filter.tr()
                : LocaleKeys.search_subtitle.tr(),
            titleShader: HomeClock.timeShader,
          ),
          // El campo va pegado al encabezado (que ya trae su aire abajo): así
          // queda a la misma distancia del subtítulo que de la grilla.
          _SearchField(
            queryController: widget.queryController,
            searchFocusNode: widget.searchFocusNode,
            clearFocusNode: widget.clearFocusNode,
            micFocusNode: _micFocusNode,
            onDictate: _dictate,
            hasQuery: hasQuery,
            onFocusUp: widget.onFocusUp,
            onFocusDown: _focusResultsFromInput,
            onClear: () {
              widget.queryController.clear();
              widget.searchFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: ChannelGridTile.gap / 2),
          Expanded(
            child: widget.showSearchPrompt
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: MoaiIcons.tvTabBuscar,
                    message: LocaleKeys.search_min_chars_prompt.tr(
                      namedArgs: {
                        'n': '${HomeSearchController.minQueryLength}',
                      },
                    ),
                    onFocusUp: _focusInputFromFirstResult,
                  )
                : widget.searchResults.isEmpty
                ? TvEmptyStateCard(
                    focusNode: _emptyFocusNode,
                    icon: MoaiIcons.clear,
                    message: LocaleKeys.search_no_results.tr(),
                    onFocusUp: _focusInputFromFirstResult,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Como Canales: tantas filas como entren enteras,
                      // estiradas hasta llenar el alto.
                      final height = constraints.maxHeight;
                      final rows = (height / _minRowExtent).floor().clamp(
                        1,
                        32,
                      );
                      return TvWindowedGrid<Channel>(
                        key: _listKey,
                        items: widget.searchResults,
                        crossAxisCount: _crossAxisCount,
                        windowSize: rows * _crossAxisCount,
                        itemExtent: height / rows,
                        initialGlobalIndex: _selectedIndex,
                        showScrollDots: true,
                        onFocusUpFromFirst: _focusInputFromFirstResult,
                        itemBuilder:
                            (
                              context,
                              channel,
                              focusNode,
                              local,
                              global,
                              onKeyUp,
                              onKeyDown,
                              onKeyLeft,
                              onKeyRight,
                            ) {
                              return ChannelGridTile(
                                key: ValueKey(channel.id),
                                channel: channel,
                                isSelected: widget.tunedChannelId == channel.id,
                                focusNode: focusNode,
                                onLongPress: widget.onLongPress,
                                onKeyUp: onKeyUp,
                                onKeyDown: onKeyDown,
                                onKeyLeft: onKeyLeft,
                                onKeyRight: onKeyRight,
                                onTap: () => widget.onSelectChannel(channel),
                              );
                            },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Campo de búsqueda, el micrófono y la "X" para borrar, con el foco de TV
/// (borde verde). → va del campo al micrófono y de ahí a la "X"; sin "X",
/// → desde el micrófono sigue al visor (lo maneja el área).
class _SearchField extends StatelessWidget {
  final TextEditingController queryController;
  final FocusNode searchFocusNode;
  final FocusNode clearFocusNode;
  final FocusNode micFocusNode;
  final VoidCallback onDictate;
  final bool hasQuery;
  final VoidCallback onFocusUp;
  final VoidCallback onFocusDown;
  final VoidCallback onClear;

  const _SearchField({
    required this.queryController,
    required this.searchFocusNode,
    required this.clearFocusNode,
    required this.micFocusNode,
    required this.onDictate,
    required this.hasQuery,
    required this.onFocusUp,
    required this.onFocusDown,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: queryController,
            focusNode: searchFocusNode,
            label: LocaleKeys.search_field_label.tr(),
            hint: LocaleKeys.search_field_hint.tr(),
            keyboardType: TvKeyboardType.search,
            textInputAction: TvTextInputAction.search,
            dense: true,
            leadingIcon: MoaiIcons.keyboard,
            accent: Theme.of(context).colorScheme.primary,
            onFocusUp: onFocusUp,
            onFocusDown: onFocusDown,
            onFocusRight: micFocusNode.requestFocus,
            onSubmitted: (_) => onFocusDown(),
          ),
        ),
        const SizedBox(width: 10),
        SearchClearButton(
          focusNode: micFocusNode,
          icon: MoaiIcons.mic,
          onClear: onDictate,
          onKeyLeft: searchFocusNode.requestFocus,
          // Sin "X": null deja que → siga al visor.
          onKeyRight: hasQuery ? clearFocusNode.requestFocus : null,
          onKeyUp: onFocusUp,
          onKeyDown: onFocusDown,
          accent: Theme.of(context).colorScheme.primary,
        ),
        if (hasQuery) ...[
          const SizedBox(width: 10),
          SearchClearButton(
            focusNode: clearFocusNode,
            onClear: onClear,
            onKeyLeft: micFocusNode.requestFocus,
            onKeyUp: onFocusUp,
            onKeyDown: onFocusDown,
            accent: Theme.of(context).colorScheme.primary,
          ),
        ],
      ],
    );
  }
}

/// "X" para borrar la búsqueda (también la usa Buscar de Películas).
class SearchClearButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  /// La "X" por defecto; el micrófono de Películas usa el mismo botón.
  final IconData icon;

  /// Color del foco: con él, el círculo de cristal no cambia y el foco es
  /// [TvFocusRing] (como el resto de TV). Sin él, el acento relleno.
  final Color? accent;

  const SearchClearButton({
    super.key,
    required this.focusNode,
    required this.onClear,
    required this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.icon = MoaiIcons.close,
    this.accent,
  });

  @override
  State<SearchClearButton> createState() => SearchClearButtonState();
}

class SearchClearButtonState extends State<SearchClearButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (widget.onKeyRight != null) {
            widget.onKeyRight!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          if (widget.onKeyUp != null) {
            widget.onKeyUp!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          if (widget.onKeyDown != null) {
            widget.onKeyDown!();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (TvKeyHandler.isActionKey(key)) {
          widget.onClear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClear,
        // Como el botón de volver: círculo de cristal en reposo y, con
        // foco, acento con brillo arriba y halo (sin escala).
        child: widget.accent != null
            ? TvFocusRing(
                focused: _isFocused,
                color: widget.accent!,
                circle: true,
                child: MoaiGlass(
                  width: 40,
                  height: 40,
                  elevated: false,
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    color: _isFocused ? widget.accent : scheme.onSurfaceVariant,
                    size: MoaiIconSizes.md,
                  ),
                ),
              )
            : _isFocused
            ? Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
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
                child: Icon(
                  widget.icon,
                  color: scheme.onPrimary,
                  size: MoaiIconSizes.md,
                ),
              )
            : MoaiGlass(
                width: 40,
                height: 40,
                elevated: false,
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  color: scheme.onSurfaceVariant,
                  size: MoaiIconSizes.md,
                ),
              ),
      ),
    );
  }
}
