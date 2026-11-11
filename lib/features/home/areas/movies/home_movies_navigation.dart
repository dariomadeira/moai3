part of '../home_movies_area.dart';

/// La navegación de la grilla: filas, ventanas, precarga y teclas.
extension _HomeMoviesNavigation on HomeMoviesAreaState {
  /// Filas de la grilla de 5 columnas que ocupa la categoría.
  int _rowCount(CategoryColumn cat) =>
      (HomeMoviesAreaState._slotCount(cat) +
          HomeMoviesAreaState._crossAxisCount -
          1) ~/
      HomeMoviesAreaState._crossAxisCount;

  /// Casilleros de la fila [row] de la categoría [cat].
  int _rowLength(int cat, int row) {
    final total = HomeMoviesAreaState._slotCount(_categories[cat]);
    final start = row * HomeMoviesAreaState._crossAxisCount;
    return (total - start).clamp(0, HomeMoviesAreaState._crossAxisCount);
  }

  int _maxFirstRow(int cat) {
    final max = _rowCount(_categories[cat]) - HomeMoviesAreaState._windowRows;
    return max < 0 ? 0 : max;
  }

  void _recomputeWindows() {
    _windows = [
      for (var c = 0; c < _categories.length; c++)
        for (var f = 0; f <= _maxFirstRow(c); f++) (c, f),
    ];
  }

  /// Lleva la selección a un lugar válido si el catálogo cambió.
  void _clampSelection() {
    if (_banner.isEmpty) _onTop = false;
    if (_best.isEmpty) _onBanner = true;
    _bestCol = _bestCol.clamp(0, _best.isEmpty ? 0 : _best.length - 1);
    if (_categories.isEmpty) {
      _cat = _row = _col = _firstRow = 0;
      return;
    }
    _cat = _cat.clamp(0, _categories.length - 1);
    _row = _row.clamp(0, _rowCount(_categories[_cat]) - 1);
    _col = _col.clamp(0, _rowLength(_cat, _row) - 1);
    _placeWindow();
  }

  /// Corre la vista lo justo para que la fila elegida quede adentro.
  void _placeWindow() {
    if (_row < _firstRow) {
      _firstRow = _row;
    } else if (_row > _firstRow + HomeMoviesAreaState._windowRows - 1) {
      _firstRow = _row - HomeMoviesAreaState._windowRows + 1;
    }
    _firstRow = _firstRow.clamp(0, _maxFirstRow(_cat));
  }

  /// Precarga las categorías vecinas al quedarse quieto: con la flecha
  /// mantenida no se acumulan decodificaciones de categorías que ya pasaron.
  void _schedulePrecache() {
    _precacheTimer?.cancel();
    _precacheTimer = Timer(
      HomeMoviesAreaState._precacheDelay,
      _precacheNeighbors,
    );
  }

  /// Los pósters de las categorías a un ↑/↓ de distancia: aparecen al
  /// instante, sin el fundido de carga.
  void _precacheNeighbors() {
    if (!mounted || _categories.isEmpty) return;
    for (final index in _onTop ? [0] : [_cat - 1, _cat + 1]) {
      if (index < 0 || index >= _categories.length) continue;
      for (final movie in _categories[index].movies) {
        final poster = movie.poster;
        if (poster == null || poster.isEmpty) continue;
        precacheImage(
          TvMovieCard.posterImage(poster),
          context,
          onError: (_, _) {},
        );
      }
    }
  }

  void _select(int cat, int row, int col) {
    if (cat != _cat || _onTop) _schedulePrecache();
    _update(() {
      _onTop = false;
      // Otra categoría: desde arriba entra por su principio y desde abajo,
      // por su final.
      if (cat != _cat) _firstRow = row == 0 ? 0 : row;
      _cat = cat;
      _row = row;
      _col = col;
      _placeWindow();
    });
  }

  /// A la página de arriba: al banner o a la fila (si hay), en la columna
  /// [col] si viene de las categorías.
  void _goTop({required bool banner, int? col}) {
    _schedulePrecache();
    _update(() {
      _onTop = true;
      _onBanner = banner || _best.isEmpty;
      if (col != null) {
        _bestCol = col.clamp(0, _best.isEmpty ? 0 : _best.length - 1);
      }
    });
    _focus.node(_onBanner ? _bannerFocus : _gridFocus);
  }

  /// ↓ desde el banner: a la fila de abajo o, si no hay, a las categorías.
  void _leaveBanner() {
    if (_best.isEmpty) {
      _goToCategories(_col);
      return;
    }
    _update(() => _onBanner = false);
    _gridFocus.requestFocus();
  }

  /// A la primera fila de la primera categoría, en la columna [col].
  void _goToCategories(int col) {
    _gridFocus.requestFocus();
    _select(0, 0, col.clamp(0, _rowLength(0, 0) - 1));
  }

  // ---------------------------------------------------------------------------
  // Teclas.
  // ---------------------------------------------------------------------------

  void _moveUp() {
    if (_row > 0) {
      _select(_cat, _row - 1, _col.clamp(0, _rowLength(_cat, _row - 1) - 1));
    } else if (_cat > 0) {
      final prev = _cat - 1;
      final lastRow = _rowCount(_categories[prev]) - 1;
      _select(prev, lastRow, _col.clamp(0, _rowLength(prev, lastRow) - 1));
    } else if (_banner.isNotEmpty) {
      _goTop(banner: false, col: _col);
    }
  }

  void _moveDown() {
    if (_row < _rowCount(_categories[_cat]) - 1) {
      _select(_cat, _row + 1, _col.clamp(0, _rowLength(_cat, _row + 1) - 1));
    } else if (_cat < _categories.length - 1) {
      final next = _cat + 1;
      _select(next, 0, _col.clamp(0, _rowLength(next, 0) - 1));
    }
  }

  KeyEventResult _onGridKey(FocusNode node, KeyEvent event) {
    // Lo que el banner no usa sube hasta acá: no mueve la grilla.
    if (_categories.isEmpty || (_onTop && _onBanner)) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (_onTop) return _onBestKey(key, repeat);

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_col > 0) {
        _select(_cat, _row, _col - 1);
      } else {
        widget.onExitLeft();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (_col < _rowLength(_cat, _row) - 1) {
        _select(_cat, _row, _col + 1);
      } else {
        // Última película de la fila: al panel Buscar.
        _openSearch();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveDown();
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      final index = _row * HomeMoviesAreaState._crossAxisCount + _col;
      final category = _categories[_cat];
      if (index < category.movies.length) {
        _onMovieTap(category.movies[index]);
      } else if (category.hasMore) {
        _openCategory(category);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// La fila "Lo mejor del año": ↑ al banner, ↓ a las categorías.
  KeyEventResult _onBestKey(LogicalKeyboardKey key, bool repeat) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_bestCol > 0) {
        _update(() => _bestCol--);
      } else {
        widget.onExitLeft();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (_bestCol < _best.length - 1) {
        _update(() => _bestCol++);
      } else {
        _openSearch();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!repeat) _goTop(banner: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _goToCategories(_bestCol);
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      _onMovieTap(_best[_bestCol]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
