part of '../home_movies_area.dart';

/// Las piezas de la grilla: banner, encabezados, filas y tarjetas.
extension _HomeMoviesView on HomeMoviesAreaState {
  /// Tamaño de las tarjetas: como en Películas de siempre, con el lugar de
  /// los puntos; si título y dos filas no entran de alto, se achican y lo
  /// que sobra de ancho va entre las columnas (como [MoviePosterGrid]).
  void _layout(double width, double height) {
    final net =
        width -
        HomeMoviesAreaState._leftPadding -
        HomeMoviesAreaState._horizontalPadding -
        MoviePositionDots.width;
    var colWidth =
        ((net -
                    (HomeMoviesAreaState._crossAxisCount - 1) *
                        HomeMoviesAreaState._gap) /
                HomeMoviesAreaState._crossAxisCount)
            .clamp(100.0, 400.0);
    var cardHeight = TvMovieCard.heightForWidth(colWidth);
    final room =
        height -
        HomeMoviesAreaState._listPadding -
        HomeMoviesAreaState._minHeaderHeight -
        (HomeMoviesAreaState._windowRows - 1) * HomeMoviesAreaState._gap -
        HomeMoviesAreaState._horizontalPadding;
    if (room > 0 && cardHeight * HomeMoviesAreaState._windowRows > room) {
      cardHeight = room / HomeMoviesAreaState._windowRows;
      colWidth = TvMovieCard.widthForHeight(cardHeight);
    }
    _cardHeight = cardHeight;
    _columnWidth = colWidth;
    _columnGap =
        (net - HomeMoviesAreaState._crossAxisCount * colWidth) /
        (HomeMoviesAreaState._crossAxisCount - 1);
    // Lo que sobra de alto con dos filas va al encabezado: el hueco de
    // abajo queda igual al de la derecha.
    _headerHeight =
        (height -
                HomeMoviesAreaState._listPadding -
                HomeMoviesAreaState._windowRows * _cardHeight -
                (HomeMoviesAreaState._windowRows - 1) *
                    HomeMoviesAreaState._gap -
                HomeMoviesAreaState._horizontalPadding)
            .clamp(HomeMoviesAreaState._minHeaderHeight, 72.0);
  }

  Widget _buildGrid(BuildContext context, ColorScheme scheme, double height) {
    // Con el foco en el banner (adentro de la grilla) no hay tarjeta elegida.
    final gridFocused = _gridFocus.hasPrimaryFocus;
    final rowsHeight =
        HomeMoviesAreaState._windowRows * _cardHeight +
        (HomeMoviesAreaState._windowRows - 1) * HomeMoviesAreaState._gap;
    final rowsTop = HomeMoviesAreaState._listPadding + _headerHeight;
    final bottom = height - rowsTop - rowsHeight;
    final hasTop = _banner.isNotEmpty;
    final windowIndex = _windows.indexOf((_cat, _firstRow));
    final page = _onTop
        ? _buildTopPage(context, scheme, gridFocused, bottom)
        : _buildCategoryPage(context, scheme, gridFocused);

    return Focus(
      focusNode: _gridFocus,
      onKeyEvent: _onGridKey,
      child: Padding(
        padding: const EdgeInsets.only(
          left: HomeMoviesAreaState._leftPadding,
          right: HomeMoviesAreaState._horizontalPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: height,
                // Entre páginas, un fundido corto; entre categorías, nada.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(key: ValueKey(_onTop), child: page),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: rowsTop),
              child: SizedBox(
                width: MoviePositionDots.width,
                height: rowsHeight,
                child: MoviePositionDots(
                  count: (hasTop ? 1 : 0) + _windows.length,
                  current: _onTop
                      ? 0
                      : (hasTop ? 1 : 0) + (windowIndex < 0 ? 0 : windowIndex),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El banner y, debajo, "Lo mejor del año" a la altura de la segunda fila
  /// de las categorías.
  Widget _buildTopPage(
    BuildContext context,
    ColorScheme scheme,
    bool gridFocused,
    double bottom,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Arriba, el mismo margen que a los costados.
        const SizedBox(height: HomeMoviesAreaState._horizontalPadding),
        Expanded(
          child: _side.isEmpty
              ? _buildBanner()
              // El banner en las tres primeras columnas de la grilla y un
              // póster en cada una de las otras dos, del alto del banner.
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildBanner()),
                    for (var c = 0; c < _side.length; c++) ...[
                      SizedBox(width: _columnGap),
                      SizedBox(
                        width: _columnWidth,
                        child: _buildTile(
                          _side[c],
                          'side_$c',
                          gridFocused && _onSide && _sideCol == c,
                          () {
                            _update(() {
                              _onTop = true;
                              _onBanner = false;
                              _onSide = true;
                              _sideCol = c;
                            });
                            _gridFocus.requestFocus();
                            _onMovieTap(_side[c]);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        if (_best.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: HomeMoviesAreaState._bestHeaderHeight,
            child: _buildHeader(
              context,
              scheme,
              LocaleKeys.movies_best_of_year.tr(
                namedArgs: {'year': '${DateTime.now().year}'},
              ),
            ),
          ),
          SizedBox(
            height: _cardHeight,
            child: _buildBestRow(
              gridFocused && !_onBanner && !_onSide ? _bestCol : -1,
            ),
          ),
        ],
        SizedBox(height: bottom),
      ],
    );
  }

  /// El título de la categoría elegida y sus dos filas a la vista.
  Widget _buildCategoryPage(
    BuildContext context,
    ColorScheme scheme,
    bool gridFocused,
  ) {
    final cat = _categories[_cat];
    final rows = _rowCount(cat);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: HomeMoviesAreaState._listPadding),
        SizedBox(
          height: _headerHeight,
          child: _buildHeader(context, scheme, cat.columnName),
        ),
        for (
          var r = _firstRow;
          r < _firstRow + HomeMoviesAreaState._windowRows;
          r++
        ) ...[
          if (r > _firstRow) const SizedBox(height: HomeMoviesAreaState._gap),
          SizedBox(
            height: _cardHeight,
            child: r < rows
                ? _buildMovieRow(
                    cat,
                    _cat,
                    r,
                    gridFocused && r == _row ? _col : -1,
                  )
                : null,
          ),
        ],
      ],
    );
  }

  /// La tarjeta destacada, con la foto a la derecha. ← sale al rail, → va a
  /// los pósters de al lado (sin ellos, a Buscar), ↓ baja a la fila; arriba
  /// no hay nada.
  Widget _buildBanner() {
    // Una tarjeta más de la grilla (2026-11-14): marco de cristal, sin
    // botones, OK abre el detalle y las destacadas pasan solas.
    return MovieHeroCard(
      movies: _banner,
      focusNode: _bannerFocus,
      wideImage: true,
      tintFromImage: true,
      elevated: false,
      showActions: false,
      glassFrame: true,
      crossFade: true,
      // Con Buscar abierto no pasa.
      autoAdvance: _panel == 0 ? HomeMoviesAreaState._bannerEvery : null,
      // Arranca con la que eligió el Inicio (si está acá) y recuerda por
      // cuál va: al volver de las categorías sigue en la misma.
      initialIndex: _rotation.chosenIndex(_banner),
      onMovieChanged: _rotation.remember,
      onOpen: _onMovieTap,
      onExitLeft: widget.onExitLeft,
      onExitRight: _side.isEmpty ? _openSearch : () => _goSide(0),
      onExitUp: () {},
      onExitDown: _leaveBanner,
    );
  }

  /// Sin contador: el usuario lo sacó (2026-11-11).
  Widget _buildHeader(BuildContext context, ColorScheme scheme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Como los títulos de los paneles: sin la barrita del acento y
            // con el degradado.
            Flexible(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: HomeClock.timeShader,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    fontSize: 18,
                    headline: true,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestRow(int selectedCol) {
    return Row(
      children: [
        for (int c = 0; c < HomeMoviesAreaState._crossAxisCount; c++) ...[
          Expanded(
            child: c < _best.length
                ? _buildTile(_best[c], 'best_$c', c == selectedCol, () {
                    _update(() {
                      _onTop = true;
                      _onBanner = false;
                      _onSide = false;
                      _bestCol = c;
                    });
                    _gridFocus.requestFocus();
                    _onMovieTap(_best[c]);
                  })
                : const SizedBox.shrink(),
          ),
          if (c < HomeMoviesAreaState._crossAxisCount - 1)
            SizedBox(width: _columnGap),
        ],
      ],
    );
  }

  /// Una fila de 5 tarjetas; [selectedCol] es la elegida (-1: ninguna).
  Widget _buildMovieRow(
    CategoryColumn cat,
    int catIdx,
    int row,
    int selectedCol,
  ) {
    final start = row * HomeMoviesAreaState._crossAxisCount;
    return Row(
      children: [
        for (int c = 0; c < HomeMoviesAreaState._crossAxisCount; c++) ...[
          Expanded(
            child: start + c < cat.movies.length
                ? _buildTile(
                    cat.movies[start + c],
                    '${catIdx}_${row}_$c',
                    selectedCol == c,
                    () {
                      _gridFocus.requestFocus();
                      _select(catIdx, row, c);
                      _onMovieTap(cat.movies[start + c]);
                    },
                  )
                : start + c == cat.movies.length && cat.hasMore
                ? RepaintBoundary(
                    child: TvShowAllCard(
                      categoryName: cat.columnName,
                      isSelected: selectedCol == c,
                      onTap: () {
                        _gridFocus.requestFocus();
                        _select(catIdx, row, c);
                        _openCategory(cat);
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (c < HomeMoviesAreaState._crossAxisCount - 1)
            SizedBox(width: _columnGap),
        ],
      ],
    );
  }

  Widget _buildTile(
    MovieItem movie,
    String fallbackKey,
    bool selected,
    VoidCallback onTap,
  ) {
    // Cada tarjeta repinta sola: mover la selección toca sólo dos.
    return RepaintBoundary(
      child: TvMovieCard(
        key: ValueKey(
          movie.contentId.isNotEmpty
              ? movie.contentId
              : '${movie.name}_$fallbackKey',
        ),
        movie: movie,
        isSelected: selected,
        onTap: onTap,
      ),
    );
  }
}
