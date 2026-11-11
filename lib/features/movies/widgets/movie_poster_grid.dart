import 'dart:math' as math;

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
    this.leftPadding,
    this.columnGap,
    this.windowRows,
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

  /// A la izquierda, si no es [horizontalPadding] (junto a la pestaña de un
  /// panel, como la grilla de Películas).
  final double? leftPadding;

  /// Entre columnas, si no es el de entre filas (12).
  final double? columnGap;

  /// Sin scroll: siempre esta cantidad de filas enteras a la vista (los
  /// pósters se achican si no entran) y ↑/↓ corren la ventana de a una fila,
  /// con los puntos de posición a la derecha, como las listas del Inicio.
  /// `null`: la lista con scroll de siempre.
  final int? windowRows;

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

  /// Con [MoviePosterGrid.windowRows]: la primera fila a la vista.
  int _firstRow = 0;

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
      _firstRow = 0;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (_index >= widget.movies.length) {
      _index = widget.movies.isEmpty ? 0 : widget.movies.length - 1;
      _placeWindow();
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

  /// Corre la ventana lo justo para que la fila elegida quede adentro.
  void _placeWindow() {
    final rows = widget.windowRows;
    if (rows == null) return;
    final row = _index ~/ columns;
    if (row < _firstRow) {
      _firstRow = row;
    } else if (row > _firstRow + rows - 1) {
      _firstRow = row - rows + 1;
    }
    final maxFirst = _rowCount - rows;
    _firstRow = _firstRow.clamp(0, maxFirst < 0 ? 0 : maxFirst);
  }

  void _reveal({bool animate = true}) {
    if (widget.windowRows != null) {
      setState(_placeWindow);
      return;
    }
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
    if (widget.windowRows case final rows?) return _windowed(context, rows);
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = widget.horizontalPadding;
        final left = widget.leftPadding ?? padding;
        final columnGap = widget.columnGap ?? _gap;
        final net =
            constraints.maxWidth - left - padding - (columns - 1) * columnGap;
        final colWidth = (net / columns).clamp(100.0, 400.0);
        // Como la grilla de Películas: el afiche entero con su margen y la
        // barra del nombre.
        final cardHeight = TvMovieCard.heightForWidth(colWidth);
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
                left,
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
                  child: _row(row, focused ? _index : -1, columnGap),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Ancho de la columna de puntos (con su separación de la grilla).
  static const double dotsWidth = MoviePositionDots.width;

  /// [rows] filas enteras sin scroll y los puntos de posición a la derecha.
  Widget _windowed(BuildContext context, int rows) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = widget.horizontalPadding;
        final left = widget.leftPadding ?? padding;
        // Los puntos tienen su lugar siempre: que aparezcan al llegar más
        // resultados no achica los pósters.
        final width = constraints.maxWidth - left - padding - dotsWidth;
        final minGap = widget.columnGap ?? _gap;
        var colWidth = (width - (columns - 1) * minGap) / columns;
        var cardHeight = TvMovieCard.heightForWidth(colWidth);
        // Si no entran las filas enteras, el póster se achica para que
        // entren y lo que sobra de ancho va entre las columnas.
        final fitHeight = (constraints.maxHeight - (rows - 1) * _gap) / rows;
        if (fitHeight > 0 && cardHeight > fitHeight) {
          cardHeight = fitHeight;
          colWidth = TvMovieCard.widthForHeight(fitHeight);
        }
        final columnGap = (width - columns * colWidth) / (columns - 1);
        _rowExtent = cardHeight + _gap;
        final focused = widget.focusNode.hasFocus;
        final last = _rowCount - 1;

        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: _onKey,
          child: Padding(
            padding: EdgeInsets.only(left: left, right: padding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var r = _firstRow; r < _firstRow + rows; r++) ...[
                        if (r > _firstRow) const SizedBox(height: _gap),
                        SizedBox(
                          height: cardHeight,
                          child: r <= last
                              ? _row(r, focused ? _index : -1, columnGap)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(
                  width: dotsWidth,
                  height: rows * cardHeight + (rows - 1) * _gap,
                  child: _dots(context, rows),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dots(BuildContext context, int rows) => MoviePositionDots(
    count: _rowCount - rows + 1,
    current: _firstRow,
    loadingMore: widget.loadingMore,
    loadFailed: widget.loadFailed,
  );

  Widget _row(int row, int selected, double columnGap) {
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
          if (c < columns - 1) SizedBox(width: columnGap),
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

/// Un punto por posición de una grilla sin scroll; el actual, estirado (como
/// en las listas del Inicio). Debajo, "cargando" o el error de la página
/// siguiente. Los usan [MoviePosterGrid] y la grilla de Películas.
class MoviePositionDots extends StatelessWidget {
  const MoviePositionDots({
    super.key,
    required this.count,
    required this.current,
    this.loadingMore = false,
    this.loadFailed = false,
  });

  final int count;
  final int current;
  final bool loadingMore;
  final bool loadFailed;

  /// Ancho de la columna (con su separación de la grilla).
  static const double width = 10 + 5 + 4;

  /// Más puntos que estos no entran al costado: se muestran los de alrededor.
  static const int _maxDots = 24;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Del ancho de los puntos: cargando, tres más que se encienden en ola
    // (las posiciones que vienen); si falló, uno rojo.
    final Widget? status = loadingMore
        ? const _LoadingDots()
        : loadFailed
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            width: 5.0,
            height: 5.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.error,
            ),
          )
        : null;
    final shown = count.clamp(0, _maxDots);
    final from = (current - shown ~/ 2).clamp(0, count - shown);
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (count > 1)
            for (var i = from; i < from + shown; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(vertical: 2.5),
                width: 5.0,
                height: i == current ? 5.0 * 2.4 : 5.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0),
                  color: i == current
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
          if (status != null) ...[const SizedBox(height: 6), status],
        ],
      ),
    );
  }
}

/// Tres puntos del tamaño de los de posición que se encienden uno tras otro,
/// en ola: la página siguiente está bajando.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2.5),
              width: 5.0,
              height: 5.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  scheme.onSurface.withValues(alpha: 0.15),
                  scheme.primary,
                  _glow(i),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Brillo del punto [i]: un pulso que baja por los tres.
  double _glow(int i) {
    final t = (_wave.value - i / 3) % 1.0;
    return t < 0.5 ? math.sin(t * 2 * math.pi).clamp(0.0, 1.0) : 0.0;
  }
}
