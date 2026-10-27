import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/controllers/movie_search_controller.dart';
import 'package:moai3/features/search/widgets/search_panel.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';

/// Panel Buscar de Películas (SPEC-45 §3): campo + "X", últimas búsquedas
/// con el campo vacío y resultados en la grilla de 5 columnas.
class MovieSearchPanel extends StatefulWidget {
  final MovieSearchController controller;
  final FocusNode fieldFocusNode;
  final FocusNode clearFocusNode;

  /// ← desde el campo o la primera columna: vuelve a la grilla.
  final VoidCallback onExitLeft;
  final ValueChanged<MovieItem> onOpenMovie;

  const MovieSearchPanel({
    super.key,
    required this.controller,
    required this.fieldFocusNode,
    required this.clearFocusNode,
    required this.onExitLeft,
    required this.onOpenMovie,
  });

  @override
  State<MovieSearchPanel> createState() => _MovieSearchPanelState();
}

class _MovieSearchPanelState extends State<MovieSearchPanel> {
  static const int _columns = 5;
  static const double _gap = 12;

  final ScrollController _scroll = ScrollController();
  final List<FocusNode> _resultNodes = [];
  final List<FocusNode> _historyNodes = [];

  MovieSearchController get _search => widget.controller;

  @override
  void dispose() {
    for (final node in [..._resultNodes, ..._historyNodes]) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _syncNodes(List<FocusNode> nodes, int count, String label) {
    while (nodes.length < count) {
      nodes.add(FocusNode(debugLabel: '${label}_${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  /// ↓ desde el campo o la "X".
  void _focusBody() {
    if (_search.showHistory) {
      if (_historyNodes.isNotEmpty) _historyNodes.first.requestFocus();
    } else if (_resultNodes.isNotEmpty) {
      _resultNodes.first.requestFocus();
    }
  }

  void _focusField() => widget.fieldFocusNode.requestFocus();

  void _clear() {
    _search.clear();
    _focusField();
  }

  void _searchRecent(String query) {
    _search.queryController.text = query;
    _search.search(query);
    _focusField();
  }

  void _focusResult(int index) {
    if (index < 0 || index >= _resultNodes.length) return;
    _resultNodes[index].requestFocus();
  }

  void _onResultFocused(int index) {
    final context = _resultNodes[index].context;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: index < _columns ? 0 : 0.8,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    final lastRow = (_search.results.length - 1) ~/ _columns;
    if (index ~/ _columns == lastRow) _search.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_search, _search.queryController]),
      builder: (context, _) {
        _syncNodes(
          _historyNodes,
          _search.showHistory ? _search.history.length : 0,
          'movie_search_recent',
        );
        _syncNodes(_resultNodes, _search.results.length, 'movie_search_result');
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (_search.isOffline) _buildOfflineNotice(context),
              const SizedBox(height: 10),
              Expanded(child: _buildBody(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final hasText = _search.queryController.text.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _search.queryController,
            focusNode: widget.fieldFocusNode,
            label: LocaleKeys.movies_panel_search_title.tr(),
            hint: LocaleKeys.movies_search_hint.tr(),
            keyboardType: TvKeyboardType.search,
            textInputAction: TvTextInputAction.search,
            dense: true,
            leadingIcon: MoaiIcons.keyboard,
            onFocusLeft: widget.onExitLeft,
            onFocusRight: hasText ? widget.clearFocusNode.requestFocus : null,
            onFocusDown: _focusBody,
            onSubmitted: _search.search,
          ),
        ),
        if (hasText) ...[
          const SizedBox(width: 8),
          SearchClearButton(
            focusNode: widget.clearFocusNode,
            onClear: _clear,
            onKeyLeft: _focusField,
            onKeyDown: _focusBody,
          ),
        ],
      ],
    );
  }

  Widget _buildOfflineNotice(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(
            MoaiIcons.moviesSearchOffline,
            size: MoaiIconSizes.sm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            LocaleKeys.movies_search_offline.tr(),
            style: MoaiText.body(
              context,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_search.showHistory) return _buildHistory(context);
    if (_search.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_search.results.isEmpty) {
      return _Message(
        icon: MoaiIcons.moviesSearch,
        text: LocaleKeys.movies_search_no_results.tr(
          namedArgs: {'query': _search.query},
        ),
      );
    }
    return _buildResults();
  }

  Widget _buildHistory(BuildContext context) {
    final history = _search.history;
    if (history.isEmpty) {
      return _Message(
        icon: MoaiIcons.moviesSearch,
        text: LocaleKeys.movies_search_empty_history.tr(),
      );
    }
    final scheme = context.scheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            LocaleKeys.movies_search_recent.tr(),
            style: MoaiText.display(
              context,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, i) => Align(
              alignment: Alignment.centerLeft,
              child: _RecentSearchTile(
                text: history[i],
                focusNode: _historyNodes[i],
                onTap: () => _searchRecent(history[i]),
                onKeyUp: i == 0
                    ? _focusField
                    : _historyNodes[i - 1].requestFocus,
                onKeyDown: i < history.length - 1
                    ? _historyNodes[i + 1].requestFocus
                    : null,
                onKeyLeft: widget.onExitLeft,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final results = _search.results;
    final rows = (results.length + _columns - 1) ~/ _columns;
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth =
            (constraints.maxWidth - (_columns - 1) * _gap) / _columns;
        // Como la grilla de Películas: afiche 262:370 + barra del título.
        final cardHeight = colWidth * (370 / 262) + 30;
        return ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: rows + (_search.isLoadingMore ? 1 : 0),
            itemBuilder: (context, row) {
              if (row >= rows) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: SizedBox(
                  height: cardHeight,
                  child: Row(
                    children: [
                      for (int c = 0; c < _columns; c++) ...[
                        if (c > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: row * _columns + c < results.length
                              ? _buildCard(row * _columns + c)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(int index) {
    final movie = _search.results[index];
    final col = index % _columns;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) _onResultFocused(index);
      },
      child: TvMovieCard(
        key: ValueKey(
          movie.contentId.isNotEmpty ? movie.contentId : '${movie.name}_$index',
        ),
        movie: movie,
        focusNode: _resultNodes[index],
        onTap: () => widget.onOpenMovie(movie),
        onKeyLeft: () {
          if (col > 0) {
            _focusResult(index - 1);
          } else {
            widget.onExitLeft();
          }
          return true;
        },
        onKeyRight: () {
          if (col < _columns - 1) _focusResult(index + 1);
          return true;
        },
        onKeyUp: () {
          if (index < _columns) {
            _focusField();
          } else {
            _focusResult(index - _columns);
          }
        },
        onKeyDown: () {
          final below = index + _columns;
          if (below < _resultNodes.length) {
            _focusResult(below);
          } else if (index ~/ _columns <
              (_resultNodes.length - 1) ~/ _columns) {
            // La fila de abajo está incompleta: a su última película.
            _focusResult(_resultNodes.length - 1);
          }
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: MoaiIconSizes.xxl,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: MoaiText.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una búsqueda reciente: OK la repite.
class _RecentSearchTile extends StatefulWidget {
  final String text;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onKeyUp;
  final VoidCallback? onKeyDown;
  final VoidCallback onKeyLeft;

  const _RecentSearchTile({
    required this.text,
    required this.focusNode,
    required this.onTap,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onKeyLeft,
  });

  @override
  State<_RecentSearchTile> createState() => _RecentSearchTileState();
}

class _RecentSearchTileState extends State<_RecentSearchTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = _focused ? scheme.onPrimary : scheme.onSurface;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          MoaiIcons.moviesSearchRecent,
          size: MoaiIconSizes.sm,
          color: color,
        ),
        const SizedBox(width: 10),
        Text(
          widget.text,
          style: MoaiText.body(
            context,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _focused = focused);
        if (focused) {
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 200),
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onKeyUp();
        } else if (key == LogicalKeyboardKey.arrowDown) {
          widget.onKeyDown?.call();
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft();
        } else if (TvKeyHandler.isActionKey(key)) {
          widget.onTap();
        } else if (key != LogicalKeyboardKey.arrowRight) {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: _focused
            ? Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: content,
              )
            : MoaiGlass(elevated: false, padding: padding, child: content),
      ),
    );
  }
}
