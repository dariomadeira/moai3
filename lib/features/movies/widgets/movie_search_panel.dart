import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/movies/widgets/movie_poster_grid.dart';
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
  /// Un solo foco para todos los resultados ([MoviePosterGrid]).
  final FocusNode _resultsFocus = FocusNode(debugLabel: 'movie_search_results');
  final List<FocusNode> _historyNodes = [];

  MovieSearchController get _search => widget.controller;

  @override
  void dispose() {
    for (final node in _historyNodes) {
      node.dispose();
    }
    _resultsFocus.dispose();
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
    } else if (_search.results.isNotEmpty) {
      _resultsFocus.requestFocus();
    }
  }

  void _focusField() => widget.fieldFocusNode.requestFocus();

  void _clear() {
    _search.clear();
    _focusField();
  }

  /// OK en una reciente: la busca (si no es la actual) y la sube al principio.
  void _searchRecent(String query) {
    _search.queryController.text = query;
    _search.submit(query);
    _focusField();
  }

  /// "Borrar búsquedas": vacía las recientes y el foco vuelve al campo.
  void _clearHistory() {
    _search.clearHistory();
    _focusField();
  }

  /// Mueve el foco entre las pastillas de recientes (la última es "Borrar
  /// búsquedas") según dónde quedaron en el [Wrap]: ←/→ dentro de la fila
  /// (← al principio sale a la grilla), ↑/↓ a la pastilla más cercana de la
  /// fila de arriba o de abajo (↑ desde la primera vuelve al campo).
  void _moveChip(int from, TraversalDirection direction) {
    final rects = [
      for (final node in _historyNodes) node.context == null ? null : node.rect,
    ];
    final here = rects[from];
    if (here == null) return;
    bool sameRow(Rect? other) =>
        other != null && (other.center.dy - here.center.dy).abs() < 4;

    switch (direction) {
      case TraversalDirection.left:
        if (from > 0 && sameRow(rects[from - 1])) {
          _historyNodes[from - 1].requestFocus();
        } else {
          widget.onExitLeft();
        }
      case TraversalDirection.right:
        if (from + 1 < rects.length && sameRow(rects[from + 1])) {
          _historyNodes[from + 1].requestFocus();
        }
      case TraversalDirection.up:
      case TraversalDirection.down:
        final up = direction == TraversalDirection.up;
        int? best;
        double? bestRowDy;
        double? bestDx;
        for (var i = 0; i < rects.length; i++) {
          final r = rects[i];
          if (r == null || sameRow(r)) continue;
          final dy = r.center.dy - here.center.dy;
          if (up ? dy >= 0 : dy <= 0) continue;
          // La fila más cercana y, en ella, la más cercana en horizontal.
          final rowDy = dy.abs();
          final dx = (r.center.dx - here.center.dx).abs();
          if (bestRowDy == null ||
              rowDy < bestRowDy - 4 ||
              ((rowDy - bestRowDy).abs() <= 4 && dx < bestDx!)) {
            best = i;
            bestRowDy = rowDy;
            bestDx = dx;
          }
        }
        if (best != null) {
          _historyNodes[best].requestFocus();
        } else if (up) {
          _focusField();
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_search, _search.queryController]),
      builder: (context, _) {
        // Una por búsqueda reciente y la última para "Borrar búsquedas".
        _syncNodes(
          _historyNodes,
          _search.showHistory && _search.history.isNotEmpty
              ? _search.history.length + 1
              : 0,
          'movie_search_recent',
        );
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
            // Sólo con "Buscar" del teclado: ni por letra ni al cerrarlo.
            onSubmitted: _search.submit,
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
        // Una al lado de la otra; si no entran, pasan a la fila siguiente.
        // Al final, "Borrar búsquedas".
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < history.length; i++)
                  _RecentSearchTile(
                    text: history[i],
                    icon: MoaiIcons.moviesSearchRecent,
                    focusNode: _historyNodes[i],
                    onTap: () => _searchRecent(history[i]),
                    onMove: (direction) => _moveChip(i, direction),
                  ),
                _RecentSearchTile(
                  text: LocaleKeys.movies_search_clear_history.tr(),
                  icon: MoaiIcons.delete,
                  focusNode: _historyNodes[history.length],
                  onTap: _clearHistory,
                  onMove: (direction) => _moveChip(history.length, direction),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Resultados en la grilla de Películas ([MoviePosterGrid]): un solo foco,
  /// alturas fijas y la página siguiente al acercarse al final.
  Widget _buildResults() {
    return MoviePosterGrid(
      movies: _search.results,
      focusNode: _resultsFocus,
      onOpen: widget.onOpenMovie,
      // Otra búsqueda: la selección y el scroll vuelven al principio.
      resetKey: _search.query,
      loadingMore: _search.isLoadingMore,
      onNearEnd: _search.loadMore,
      onExitLeft: widget.onExitLeft,
      onExitUp: _focusField,
      horizontalPadding: 0,
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

/// Una pastilla de las recientes: una búsqueda (OK la repite) o "Borrar
/// búsquedas". Las flechas las resuelve el panel según dónde quedó.
class _RecentSearchTile extends StatefulWidget {
  final String text;
  final IconData icon;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<TraversalDirection> onMove;

  const _RecentSearchTile({
    required this.text,
    required this.icon,
    required this.focusNode,
    required this.onTap,
    required this.onMove,
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
        Icon(widget.icon, size: MoaiIconSizes.sm, color: color),
        const SizedBox(width: 10),
        // Una búsqueda muy larga se corta en vez de desbordar la fila.
        Flexible(
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(context, fontSize: 14, color: color),
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
        final direction = switch (key) {
          LogicalKeyboardKey.arrowUp => TraversalDirection.up,
          LogicalKeyboardKey.arrowDown => TraversalDirection.down,
          LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
          LogicalKeyboardKey.arrowRight => TraversalDirection.right,
          _ => null,
        };
        if (direction != null) {
          widget.onMove(direction);
        } else if (TvKeyHandler.isActionKey(key)) {
          widget.onTap();
        } else {
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
