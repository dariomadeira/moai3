import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_grid_catalog.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Grilla de pósters de 5 columnas para listas largas que se cargan de a
/// páginas: "Ver todas" (SPEC-44 §3.3) y los resultados de Buscar (SPEC-45).
///
/// Como la grilla de Películas, tiene un único [focusNode]: la película
/// elegida es un índice y las tarjetas sólo la dibujan; todas las filas miden
/// lo mismo y el scroll se calcula. Lo que se agrega abajo no mueve el foco.
class MoviePosterGrid extends StatefulWidget {
  const MoviePosterGrid({
    super.key,
    required this.movies,
    required this.focusNode,
    required this.onOpen,
    this.resetKey,
    this.loadingMore = false,
    this.loadFailed = false,
    this.onNearEnd,
    this.onExitLeft,
    this.onExitUp,
    this.horizontalPadding = 14,
  });

  final List<MovieItem> movies;
  final FocusNode focusNode;

  /// OK (o toque) sobre una película.
  final ValueChanged<MovieItem> onOpen;

  /// Cuando cambia (p. ej. otra búsqueda), la selección vuelve al principio.
  final Object? resetKey;

  /// Al pie, una fila de "cargando" ([loadingMore]) o de error ([loadFailed]).
  final bool loadingMore;
  final bool loadFailed;

  /// La elegida quedó a [MoviePosterGridState.prefetchRows] filas o menos
  /// del final (o ↓ en la última): momento de pedir más.
  final VoidCallback? onNearEnd;

  /// ← desde la primera columna; ↑ desde la primera fila.
  final VoidCallback? onExitLeft;
  final VoidCallback? onExitUp;

  final double horizontalPadding;

  @override
  State<MoviePosterGrid> createState() => MoviePosterGridState();
}

class MoviePosterGridState extends State<MoviePosterGrid> {
  static const int columns = 5;
  static const int prefetchRows = 2;
  static const double _gap = 12.0;
  static const double _listPadding = 8.0;

  final _scroll = ScrollController();
  int _index = 0;
  double _rowExtent = 0;

  /// Película elegida (índice en [MoviePosterGrid.movies]).
  int get index => _index;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant MoviePosterGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
    if (oldWidget.resetKey != widget.resetKey) {
      _index = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (_index >= widget.movies.length) {
      _index = widget.movies.isEmpty ? 0 : widget.movies.length - 1;
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() {});
    // Al volver (p. ej. del detalle) la elegida queda a la vista.
    if (widget.focusNode.hasFocus) _reveal(animate: false);
  }

  int get _rowCount => (widget.movies.length + columns - 1) ~/ columns;

  void _select(int index) {
    setState(() => _index = index);
    _reveal();
    if (_rowCount - 1 - index ~/ columns <= prefetchRows) {
      widget.onNearEnd?.call();
    }
  }

  void _reveal({bool animate = true}) {
    if (!_scroll.hasClients || _rowExtent <= 0) return;
    final position = _scroll.position;
    final row = _index ~/ columns;
    final top = _listPadding + row * _rowExtent;
    final bottom = top + _rowExtent + _listPadding;
    var target = position.pixels;
    if (row == 0) {
      target = 0;
    } else if (top < target) {
      target = top;
    } else if (bottom > target + position.viewportDimension) {
      target = bottom - position.viewportDimension;
    }
    target = target.clamp(0.0, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) return;
    if (animate) {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final movies = widget.movies;
    if (movies.isEmpty) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    final col = _index % columns;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (col > 0) {
        _select(_index - 1);
      } else {
        widget.onExitLeft?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (col < columns - 1 && _index + 1 < movies.length) {
        _select(_index + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_index >= columns) {
        _select(_index - columns);
      } else if (!repeat) {
        widget.onExitUp?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final below = _index + columns;
      if (below < movies.length) {
        _select(below);
      } else if (below ~/ columns < _rowCount) {
        // Fila de abajo incompleta: a su última película.
        _select(movies.length - 1);
      } else {
        // Ya en la última fila: que siga cargando si hay más.
        widget.onNearEnd?.call();
      }
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      widget.onOpen(movies[_index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = widget.horizontalPadding;
        final net = constraints.maxWidth - padding * 2 - (columns - 1) * _gap;
        final colWidth = (net / columns).clamp(100.0, 400.0);
        // Misma proporción de afiche que la grilla de Películas (262:370)
        // más la barra del título.
        final cardHeight = colWidth * (370 / 262) + 30.0;
        _rowExtent = cardHeight + _gap;
        final footer = widget.loadingMore || widget.loadFailed ? 1 : 0;
        final focused = widget.focusNode.hasFocus;

        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: _onKey,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                padding,
                _listPadding,
                padding,
                _listPadding,
              ),
              itemExtent: _rowExtent,
              itemCount: _rowCount + footer,
              itemBuilder: (context, row) {
                if (row >= _rowCount) return _footer(context);
                return Padding(
                  padding: const EdgeInsets.only(bottom: _gap),
                  child: _row(row, focused ? _index : -1),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _row(int row, int selected) {
    final movies = widget.movies;
    final start = row * columns;
    return Row(
      children: [
        for (var c = 0; c < columns; c++) ...[
          Expanded(
            child: start + c < movies.length
                ? RepaintBoundary(
                    child: TvMovieCard(
                      key: ValueKey(MovieGridCatalog.keyOf(movies[start + c])),
                      movie: movies[start + c],
                      isSelected: selected == start + c,
                      onTap: () {
                        widget.focusNode.requestFocus();
                        _select(start + c);
                        widget.onOpen(movies[start + c]);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (c < columns - 1) const SizedBox(width: _gap),
        ],
      ],
    );
  }

  /// Pie mientras baja la página siguiente (o si falló: se reintenta al
  /// volver a bajar).
  Widget _footer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: widget.loadingMore
          ? const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : Icon(
              MoaiIcons.error,
              size: MoaiIconSizes.lg,
              color: scheme.outline,
            ),
    );
  }
}
