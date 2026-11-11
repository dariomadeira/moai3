part of '../home_dashboard_area.dart';

/// Cada tarjeta del Inicio: cuál va, cómo se arma y sus acciones.
extension _HomeDashboardItems on HomeDashboardAreaState {
  /// Dónde está la tarjeta con el foco en [items]; si ya no está (o todavía
  /// no se eligió ninguna), la primera.
  int _selectedIndexIn(List<_HomeWidget> items) {
    final index = _selected == null ? -1 : items.indexOf(_selected!);
    return index < 0 ? 0 : index;
  }

  /// Cada tarjeta con su manejo de teclas.
  Widget _buildItem(
    _HomeWidget item,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
    List<MovieItem> trailers,
    List<MovieItem> heroMovies,
  ) {
    switch (item) {
      case _HomeWidget.hero:
        return _buildHero(heroMovies, focusNode, onKeyUp, onKeyDown);
      case _HomeWidget.events:
        return _buildEventsItem(focusNode, onKeyUp, onKeyDown);
      case _HomeWidget.friends:
        return HomeFriendsItem(
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onTuneChannel: widget.onTuneChannel,
        );
      case _HomeWidget.friendRequests:
        return HomeFriendRequestsItem(
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _HomeWidget.discounts:
        return HomeDiscountsItem(
          onOpen: widget.onOpenDiscounts,
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
        );
      case _HomeWidget.continueWatching:
        return _MovieListItem(
          focusNode: focusNode,
          movies: _continue,
          initialIndex: _continueIndex,
          onIndexChanged: (i) => _continueIndex = i,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _resumeMovie,
          onRemove: _confirmMarkWatched,
          onClearAll: _confirmMarkAllWatched,
          buildCard: (selected, focused) => HomeContinueCard(
            movies: _continue,
            selectedIndex: selected,
            isFocused: focused,
            watched: _continueWatched,
            loadingId: _resumingId,
          ),
        );
      case _HomeWidget.seriesContinue:
        return _MovieListItem(
          focusNode: focusNode,
          movies: [
            for (final item in _seriesContinue)
              HomeSeriesContinueCard.movieOf(item),
          ],
          initialIndex: _seriesContinueIndex,
          onIndexChanged: (i) => _seriesContinueIndex = i,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openSeries,
          onRemove: _confirmRemoveSeries,
          onClearAll: _confirmClearSeries,
          buildCard: (selected, focused) => HomeSeriesContinueCard(
            items: _seriesContinue,
            selectedIndex: selected,
            isFocused: focused,
          ),
        );
      case _HomeWidget.recommendations:
        return _MovieListItem(
          focusNode: focusNode,
          movies: [for (final item in _recommendations) item.movie],
          initialIndex: _recommendationIndex,
          onIndexChanged: (i) => _recommendationIndex = i,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openMovie,
          onRemove: _confirmDismissRecommendation,
          onClearAll: _confirmDismissAllRecommendations,
          buildCard: (selected, focused) => HomeRecommendationsCard(
            items: _recommendations,
            selectedIndex: selected,
            isFocused: focused,
          ),
        );
      case _HomeWidget.watchlistBig:
        final movies = MovieWatchlistService.instance.movies;
        return _MovieListItem(
          focusNode: focusNode,
          movies: movies,
          initialIndex: _watchlistIndex,
          onIndexChanged: (i) => _watchlistIndex = i,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openMovie,
          onRemove: _confirmRemoveFromWatchlist,
          onClearAll: _confirmClearWatchlist,
          buildCard: (selected, focused) => HomeWatchlistBigCard(
            movies: movies,
            selectedIndex: selected,
            isFocused: focused,
          ),
        );
      case _HomeWidget.trailers:
        return _TrailersItem(
          focusNode: focusNode,
          trailers: trailers,
          initialIndex: _trailerIndex,
          onIndexChanged: (i) => _trailerIndex = i,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openMovie,
        );
      case _HomeWidget.weather:
        // Sólo informa: no toma el foco (ver canFocus).
        return _HomeWidgetItem(
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          builder: (_) => _buildWeather(),
        );
      case _HomeWidget.arcade:
        return _HomeWidgetItem(
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onPress: _runArcadeAction,
          onLeft: () => _moveArcadeAction(-1),
          onRight: () => _moveArcadeAction(1),
          builder: _buildArcade,
        );
    }
  }

  /// Escucha el clima con el context de su propia tarjeta ([Builder]): al
  /// actualizarse se redibuja sólo ella, no todo el Inicio.
  Widget _buildWeather() => Builder(builder: _weatherCard);

  Widget _weatherCard(BuildContext context) {
    final weatherProvider = context.watch<WeatherProvider?>();
    final weather = weatherProvider?.weather;
    if (weather == null) {
      // Todavía sin datos: el lugar, vacío.
      return const MoaiGlass(
        borderRadius: HomeWeatherCard.radius,
        solid: true,
        elevated: false,
        child: SizedBox.expand(),
      );
    }
    return HomeWeatherCard(
      weather: weather,
      now: _now,
      place: weatherProvider?.placeName,
    );
  }

  Widget _buildArcade(bool isFocused) {
    final rom = widget.romManager.activeRom;
    if (rom == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: _arcadeAction,
      builder: (context, action, _) => HomeArcadeCard(
        romName: widget.romManager.displayNameOf(rom),
        details: [
          rom.company,
          rom.year,
        ].where((s) => s.trim().isNotEmpty).join('  ·  '),
        selectedAction: action,
        isFocused: isFocused,
        canInvite: _canInvite,
      ),
    );
  }

  bool _moveArcadeAction(int delta) {
    final next = _arcadeAction.value.index + delta;
    // Sin amigos conectados, "Invitar" no está.
    final count = HomeArcadeAction.values.length - (_canInvite ? 0 : 1);
    if (next < 0 || next >= count) return false;
    _arcadeAction.value = HomeArcadeAction.values[next];
    return true;
  }

  /// OK en el widget de Arcade: como "Iniciar juego", "Seleccionar juego" y
  /// "Jugar juntos" del área de Arcade.
  void _runArcadeAction() {
    switch (_arcadeAction.value) {
      case HomeArcadeAction.start:
        final path = widget.romManager.getActiveRomPath();
        if (path != null) {
          unawaited(ArcadeLauncher.play(context, romPath: path));
        }
      case HomeArcadeAction.change:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArcadeGamesScreen(romManager: widget.romManager),
          ),
        );
      case HomeArcadeAction.invite:
        ArcadeLauncher.playTogether(context, widget.romManager);
    }
  }

  /// Widget de eventos de hoy: ←/→ eligen el evento y OK abre su detalle.
  Widget _buildEventsItem(
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) {
    final events = _todayEvents(context.watch<CalendarProvider>());

    return _EventsItem(
      focusNode: focusNode,
      events: events,
      // Se recuerda acá (sin reconstruir el Inicio): la tarjeta sale de la
      // página y al volver sigue en el mismo evento.
      initialIndex: _eventIndex,
      onIndexChanged: (i) => _eventIndex = i,
      onKeyLeft: widget.onExitLeft,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      onOpen: (event) => showCalendarEventDetails(
        context,
        event,
        onTuneChannel: widget.onTuneChannel,
      ),
    );
  }
}
