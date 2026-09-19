import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/search/controllers/home_search_controller.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';

/// Panel Buscar: header compacto propio + ventana fija de 6 (como Canales).
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
    required this.onLongPress,
    required this.onSelectChannel,
  });

  @override
  State<SearchPanel> createState() => SearchPanelState();
}

class SearchPanelState extends State<SearchPanel> {
  static const int _windowSize = 6;

  final _listKey = GlobalKey<TvWindowedListState<Channel>>();

  int get _selectedIndex {
    final id = widget.selectedChannel?.id;
    if (id == null) return 0;
    final idx = widget.searchResults.indexWhere((c) => c.id == id);
    if (idx >= 0) return idx;
    return 0;
  }

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

  void _focusResultsFromInput() {
    if (widget.searchResults.isEmpty) return;
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
    final scheme = context.scheme;
    final hasQuery = widget.queryController.text.isNotEmpty;
    final listAlign = widget.searchResults.length < _windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return Container(
      padding: const EdgeInsets.only(
        left: 4,
        right: 12,
        top: 6,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header compacto propio de Buscar (libera alto para 6 ítems).
          _SearchPanelChrome(
            queryController: widget.queryController,
            searchFocusNode: widget.searchFocusNode,
            clearFocusNode: widget.clearFocusNode,
            hasQuery: hasQuery,
            showFilterHint: widget.searchResults.length > 1,
            resultsCapped: widget.resultsCapped && !widget.showSearchPrompt,
            onFocusUp: widget.onFocusUp,
            onFocusDown: _focusResultsFromInput,
            onClear: () {
              widget.queryController.clear();
              widget.searchFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 6),
          Expanded(
            child: widget.showSearchPrompt
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          size: 36,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'search_min_chars_prompt'.tr(
                            namedArgs: {
                              'n': '${HomeSearchController.minQueryLength}',
                            },
                          ),
                          textAlign: TextAlign.center,
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  )
                : widget.searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 36,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'search_no_results'.tr(),
                              textAlign: TextAlign.center,
                              style: MoaiText.body(
                                context,
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Align(
                        alignment: listAlign,
                        child: TvWindowedList<Channel>(
                          key: _listKey,
                          items: widget.searchResults,
                          windowSize: _windowSize,
                          initialGlobalIndex: _selectedIndex,
                          itemExtent: TvLayoutConstants.channelItemHeight,
                          onFocusUpFromFirst: _focusInputFromFirstResult,
                          itemBuilder: (
                            context,
                            channel,
                            focusNode,
                            local,
                            global,
                            onKeyUp,
                            onKeyDown,
                          ) {
                            return NewChannelCard(
                              key: ValueKey(channel.id),
                              channel: channel,
                              isSelected:
                                  widget.selectedChannel?.id == channel.id,
                              focusNode: focusNode,
                              onLongPress: widget.onLongPress,
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                              onTap: () => widget.onSelectChannel(channel),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Chrome de Buscar: campo + hint en una sola pieza.
class _SearchPanelChrome extends StatelessWidget {
  final TextEditingController queryController;
  final FocusNode searchFocusNode;
  final FocusNode clearFocusNode;
  final bool hasQuery;
  final bool showFilterHint;
  final bool resultsCapped;
  final VoidCallback onFocusUp;
  final VoidCallback onFocusDown;
  final VoidCallback onClear;

  const _SearchPanelChrome({
    required this.queryController,
    required this.searchFocusNode,
    required this.clearFocusNode,
    required this.hasQuery,
    required this.showFilterHint,
    required this.resultsCapped,
    required this.onFocusUp,
    required this.onFocusDown,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TvTextField(
                controller: queryController,
                focusNode: searchFocusNode,
                label: 'search_field_label'.tr(),
                hint: 'search_field_hint'.tr(),
                keyboardType: TvKeyboardType.search,
                textInputAction: TvTextInputAction.search,
                dense: true,
                leadingIcon: Icons.keyboard_alt_outlined,
                onFocusUp: onFocusUp,
                onFocusDown: onFocusDown,
                // Con X visible: → va al clear, no al panel Países.
                onFocusRight: hasQuery
                    ? () => clearFocusNode.requestFocus()
                    : null,
                onSubmitted: (_) => onFocusDown(),
              ),
            ),
            if (hasQuery) ...[
              const SizedBox(width: 8),
              _SearchClearButton(
                focusNode: clearFocusNode,
                onClear: onClear,
                onKeyLeft: () => searchFocusNode.requestFocus(),
                onKeyUp: onFocusUp,
                onKeyDown: onFocusDown,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          resultsCapped
              ? 'search_results_capped'.tr()
              : showFilterHint
                  ? 'search_hint_with_filter'.tr()
                  : 'search_hint_open_keyboard'.tr(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: scheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SearchClearButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onClear;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const _SearchClearButton({
    required this.focusNode,
    required this.onClear,
    required this.onKeyLeft,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<_SearchClearButton> createState() => _SearchClearButtonState();
}

class _SearchClearButtonState extends State<_SearchClearButton> {
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
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space) {
          widget.onClear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClear,
        child: AnimatedScale(
          scale: _isFocused ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isFocused ? scheme.primary : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.clear,
              color: _isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

