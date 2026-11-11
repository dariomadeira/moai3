import 'dart:async';

import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/calendar/widgets/calendar_event_details_dialog.dart';
import 'package:moai3/features/games/arcade_launcher.dart';
import 'package:moai3/features/games/screens/arcade_games_screen.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/widgets/home_arcade_card.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/home/widgets/home_continue_card.dart';
import 'package:moai3/features/home/widgets/home_discounts_card.dart';
import 'package:moai3/features/home/widgets/home_watchlist_big_card.dart';
import 'package:moai3/features/home/widgets/home_events_card.dart';
import 'package:moai3/features/home/widgets/home_friend_requests_card.dart';
import 'package:moai3/features/home/widgets/home_friends_card.dart';
import 'package:moai3/features/home/widgets/home_movie_big_card.dart';
import 'package:moai3/features/home/widgets/home_recommendations_card.dart';
import 'package:moai3/features/home/widgets/home_trailers_card.dart';
import 'package:moai3/features/home/widgets/home_weather_card.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/widgets/movie_hero_card.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/home_hero_rotation.dart';
import 'package:moai3/services/movie_library.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/services/tmdb_trending_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/home_trailers_provider.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';

part 'home_dashboard_movies.dart';

/// Área de Inicio (Dashboard).
/// Panel único a ancho completo con estilo de acordeón TV.
class HomeDashboardArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  /// Sintonizar un canal desde el detalle de un evento.
  final ValueChanged<Channel>? onTuneChannel;

  /// Ir a Descuentos (tarjeta de descuentos): a un día o a Configurar.
  final void Function({int dayIndex, bool settings})? onOpenDiscounts;

  /// ROMs del Arcade: el widget de Arcade muestra la activa.
  final ArcadeRomManagerService romManager;

  /// La hora (saludo y reloj); por defecto la del equipo. Los tests la fijan
  /// para que las fotos (golden) salgan siempre iguales.
  final DateTime Function()? now;

  const HomeDashboardArea({
    super.key,
    required this.onExitLeft,
    required this.romManager,
    this.onTuneChannel,
    this.onOpenDiscounts,
    @visibleForTesting this.now,
  });

  @override
  State<HomeDashboardArea> createState() => HomeDashboardAreaState();
}

class HomeDashboardAreaState extends HomeAreaState<HomeDashboardArea>
    with _HomeMovieCards {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final FocusNode _panelFocusNode = FocusNode(
    debugLabel: 'home_dashboard_panel',
  );
  final _listKey = GlobalKey<TvWindowedListState<_HomeWidget>>();

  /// La tarjeta con el foco (no su lugar: al aparecer o irse otra, por
  /// ejemplo cuando cargan los adelantos, el foco sigue en la misma).
  _HomeWidget? _selected;

  /// Películas de la tarjeta destacada: las primeras de "Estrenos de
  /// Cartelera".
  static const int _heroCount = 6;

  /// Evento elegido en el widget de eventos (←/→).
  int _eventIndex = 0;

  /// Acción elegida en el widget de Arcade (←/→). Avisa sola: cambiarla
  /// redibuja sólo la tarjeta, no todo el Inicio.
  final _arcadeAction = ValueNotifier(HomeArcadeAction.start);
  Timer? _hourTimer;
  late DateTime _now = _clock();

  DateTime _clock() => (widget.now ?? DateTime.now)();

  /// Siempre se ven 4 lugares: cada uno la cuarta parte del alto (en el TV,
  /// unos 107 puntos), como mucho [_maxItemExtent]. Las tarjetas grandes
  /// ocupan dos.
  static const int _windowSize = 4;
  static const double _maxItemExtent = 140;

  /// Lugares que ocupa cada tarjeta.
  static int _spanOf(_HomeWidget item) => switch (item) {
    _HomeWidget.hero ||
    _HomeWidget.continueWatching ||
    _HomeWidget.recommendations ||
    _HomeWidget.watchlistBig => 2,
    _ => 1,
  };

  @override
  void initState() {
    super.initState();
    _scheduleNextHour();
    // El widget de Arcade aparece/desaparece con el plugin y la ROM activa.
    ArcadePluginService.instance.addListener(_onArcadeChanged);
    widget.romManager.addListener(_onArcadeChanged);
    MovieWatchlistService.instance.addListener(_onWatchlistChanged);
    unawaited(_loadContinue());
    if (!HomeHeroRotation.isLoaded) {
      unawaited(
        HomeHeroRotation.load().then((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshRecommendations(),
    );
  }

  void _onWatchlistChanged() {
    if (mounted) setState(() {});
  }

  void _onArcadeChanged() {
    if (mounted) setState(() {});
  }

  /// Tarjetas visibles, en orden de prioridad y acomodadas en páginas de
  /// [_windowSize] lugares sin huecos ([TvWindowedList.packPages]): las que
  /// salen dependen de lo que el usuario tenga habilitado. Las de películas
  /// (la destacada, "Seguir viendo" e "Interesantes") sólo si Películas
  /// está en el rail ([moviesVisible]) y tienen algo; "Adelantos" (de TMDb,
  /// no del portal) sólo depende de su ajuste; Arcade, con el plugin
  /// instalado y una ROM activa.
  List<_HomeWidget> _visibleWidgets({
    required bool hasHero,
    required bool moviesVisible,
    required bool hasTrailers,
    required bool hasEventsToday,
    required bool watchPartyEnabled,
    required bool hasFriendRequests,
  }) => TvWindowedList.packPages(
    [
      if (moviesVisible && hasHero) _HomeWidget.hero,
      _HomeWidget.weather,
      // Sin nada por ver hoy (en curso o por empezar), no ocupa lugar.
      if (hasEventsToday) _HomeWidget.events,
      if (moviesVisible && _continue.isNotEmpty) _HomeWidget.continueWatching,
      if (moviesVisible && _recommendations.isNotEmpty)
        _HomeWidget.recommendations,
      _HomeWidget.discounts,
      // Amigos conectados y su canal: sólo con Miremos Juntos activado.
      if (watchPartyEnabled) _HomeWidget.friends,
      // Solicitudes de amistad recibidas: sólo si hay alguna.
      if (watchPartyEnabled && hasFriendRequests) _HomeWidget.friendRequests,
      if (moviesVisible && MovieWatchlistService.instance.movies.isNotEmpty)
        _HomeWidget.watchlistBig,
      if (hasTrailers) _HomeWidget.trailers,
      if (ArcadePluginService.instance.isInstalled &&
          widget.romManager.activeRom != null)
        _HomeWidget.arcade,
    ],
    pageSize: _windowSize,
    span: _spanOf,
  );

  /// Refresca saludo y próximas horas del clima al cambiar la hora.
  void _scheduleNextHour() {
    final now = _clock();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _hourTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = _clock());
      _scheduleNextHour();
    });
  }

  /// REDISEÑO: la fila destacada, un ítem de la lista que ocupa dos lugares:
  /// la tarjeta de la película a la mitad del ancho (a 2/3 quedaba muy
  /// estirada) y, en la otra mitad, un recuadro de cristal.
  Widget _buildHero(
    List<MovieItem> movies,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              // Mitad menos la mitad del espacio entre los dos.
              width: (constraints.maxWidth - 16) / 2,
              child: MovieHeroCard(
                movies: movies,
                focusNode: focusNode,
                tintFromImage: true,
                initialIndex: HomeHeroRotation.startIndex(movies),
                onMovieChanged: HomeHeroRotation.remember,
                onPlay: (movie) async {
                  await playMovie(context, movie);
                  await _reloadProgress();
                },
                onOpen: _openMovie,
                onToggleInteresting: MovieWatchlistService.instance.toggle,
                isInteresting: (movie) =>
                    MovieWatchlistService.instance.contains(movie.contentId),
                onExitLeft: widget.onExitLeft,
                onExitUp: onKeyUp,
                onExitDown: onKeyDown,
              ),
            ),
            const SizedBox(width: 16),
            // REDISEÑO: recuadro al lado de la tarjeta, con el mismo cristal
            // que las tarjetas de abajo; por ahora vacío.
            const Expanded(
              child: MoaiGlass(
                borderRadius: 16,
                solid: true,
                elevated: false,
                child: SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Eventos de hoy que se pueden ver: en curso o por empezar (los
  /// terminados, no).
  List<CalendarEvent> _todayEvents(CalendarProvider calendar) => calendar
      .getEventsForDay(ArgentinaTime.now())
      .where((e) => e.status != CalendarEventStatus.finished)
      .toList();

  /// Saludo según la hora: mañana 6–12, tarde 12–20, noche 20–6.
  static String greetingKey(DateTime time) {
    final h = time.hour;
    if (h >= 6 && h < 12) return LocaleKeys.home_greeting_morning;
    if (h >= 12 && h < 20) return LocaleKeys.home_greeting_afternoon;
    return LocaleKeys.home_greeting_night;
  }

  @override
  void requestEntryFocus() {
    if (!mounted) return;
    _focus.node(_panelFocusNode);
  }

  @override
  void dispose() {
    ArcadePluginService.instance.removeListener(_onArcadeChanged);
    widget.romManager.removeListener(_onArcadeChanged);
    MovieWatchlistService.instance.removeListener(_onWatchlistChanged);
    _hourTimer?.cancel();
    _arcadeAction.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Misma condición que el ítem Películas del rail (login y catálogo).
    // Eventos de hoy en curso o por empezar: sin ninguno, la tarjeta no se
    // muestra. Se recalcula cuando el calendario avisa (también cuando un
    // evento empieza o termina).
    final hasEventsToday = context.select(
      (CalendarProvider? c) =>
          c != null &&
          c
              .getEventsForDay(ArgentinaTime.now())
              .any((e) => e.status != CalendarEventStatus.finished),
    );
    // Con amigos conectados la tarjeta de Arcade ofrece "Invitar"; si el
    // último se desconecta con "Invitar" elegido, vuelve a "Jugar".
    final canInvite = context.select(
      (WatchPartyProvider? w) => w?.hasOnlineFriends ?? false,
    );
    if (!canInvite && _arcadeAction.value == HomeArcadeAction.invite) {
      _arcadeAction.value = HomeArcadeAction.start;
    }
    final watchPartyEnabled = context.select(
      (WatchPartyProvider? w) => w?.enabled ?? false,
    );
    final hasFriendRequests = context.select(
      (WatchPartyProvider? w) => w?.friendRequests.isNotEmpty ?? false,
    );
    // Ajustes › Películas y series puede apagar la tarjeta de adelantos.
    final showTrailers = context.select(
      (TvSettingsProvider? s) => s?.showHomeTrailers ?? true,
    );
    final moviesVisible = context.select(
      (FeaturedMoviesProvider? p) =>
          p?.isSectionAvailable(FeaturedMoviesProvider.sectionMovies) ?? false,
    );
    // La fila "Estrenos de Cartelera" (de TMDb), si Películas ya cargó.
    final trending = context.select(
      (FeaturedMoviesProvider? p) => p
          ?.categoriesFor(FeaturedMoviesProvider.sectionMovies)
          .where((c) => c.columnId == TmdbTrendingService.trendingColumnId)
          .firstOrNull,
    );
    // Sin saber todavía cuál vio la vez anterior, la destacada espera (si
    // no, empezaría por la primera y saltaría).
    final heroMovies = moviesVisible && HomeHeroRotation.isLoaded
        ? (trending?.movies.take(_heroCount).toList() ?? const <MovieItem>[])
        : const <MovieItem>[];
    final trailers = context.select(
      (HomeTrailersProvider? p) => p?.trailers ?? const <MovieItem>[],
    );
    if (moviesVisible) _ensureMoviesLoaded();
    if (showTrailers) _ensureTrailersLoaded();
    _recommendations = context.select(
      (MovieRecommendationsProvider? r) =>
          r?.items ?? const <FriendRecommendation>[],
    );
    final items = _visibleWidgets(
      hasHero: heroMovies.isNotEmpty,
      hasEventsToday: hasEventsToday,
      watchPartyEnabled: watchPartyEnabled,
      hasFriendRequests: hasFriendRequests,
      moviesVisible: moviesVisible,
      hasTrailers: showTrailers && trailers.isNotEmpty,
    );

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface.withValues(alpha: 0.8)],
      titles: [LocaleKeys.home_panel_home_title.tr()],
      icons: const [MoaiIcons.tvAccordionHome],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        return Focus(
          focusNode: _panelFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.onExitLeft();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _listKey.currentState?.ensureVisible(_selectedIndexIn(items));
            }
          },
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.only(
                  left: 4,
                  right: 12,
                  top: 8,
                  bottom: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo a la izquierda y la hora a la derecha: en el
                    // Inicio el reloj del rail no se ve.
                    Row(
                      children: [
                        Expanded(
                          child: TvPanelHeader(
                            title: greetingKey(_now).tr(),
                            subtitle: LocaleKeys.home_panel_home_subtitle.tr(),
                            // Degradado como los demás títulos de panel.
                            titleShader: HomeClock.timeShader,
                            // El subtítulo y la fecha del reloj, en la
                            // tinta suave del modo.
                            subtitleColor: MoaiPalette.of(context).inkSoft,
                          ),
                        ),
                        // REDISEÑO: el logo antes del reloj (el del rail
                        // se va a sacar).
                        SvgPicture.asset(
                          'assets/svgs/appLogo.svg',
                          height: 26,
                          colorFilter: ColorFilter.mode(
                            MoaiPalette.of(context).inkMuted,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: HomeClock(now: widget.now),
                        ),
                      ],
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final itemExtent =
                              (constraints.maxHeight / _windowSize).clamp(
                                0.0,
                                _maxItemExtent,
                              );
                          final targetHeight = _windowSize * itemExtent;
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: targetHeight,
                              child: TvWindowedList<_HomeWidget>(
                                key: _listKey,
                                // La entrada de foco la decide el área (rail →).
                                focusOnMount: false,
                                items: items,
                                windowSize: _windowSize,
                                itemExtent: itemExtent,
                                showScrollDots: true,
                                paged: true,
                                itemSpan: _spanOf,
                                // El clima sólo informa: ↑/↓ lo saltean.
                                // Amigos sin nadie conectado sí se enfoca:
                                // OK abre Gestionar amigos.
                                canFocus: (item) => item != _HomeWidget.weather,
                                initialGlobalIndex: _selectedIndexIn(items),
                                onFocusedGlobalIndex: (idx) =>
                                    _selected = items[idx],
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
                                        vertical: 4,
                                      ),
                                      // Por tarjeta, no por lugar: al cambiar
                                      // la página ninguna hereda el estado
                                      // (la selección) de otra.
                                      child: KeyedSubtree(
                                        key: ValueKey(item),
                                        child: _buildItem(
                                          item,
                                          focusNode,
                                          onKeyUp,
                                          onKeyDown,
                                          trailers,
                                          heroMovies,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  /// ←/→ en el widget de Arcade. Devuelve si se movió (← desde la primera
  /// acción sale al rail).
  /// Hay algún amigo conectado: la tarjeta de Arcade ofrece "Invitar".
  bool get _canInvite =>
      context.read<WatchPartyProvider?>()?.hasOnlineFriends ?? false;

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

/// La tarjeta de eventos con su propia selección: ←/→ reconstruyen sólo
/// esta tarjeta, no todo el Inicio.
class _EventsItem extends StatefulWidget {
  const _EventsItem({
    required this.focusNode,
    required this.events,
    required this.initialIndex,
    required this.onIndexChanged,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onOpen,
  });

  final FocusNode focusNode;
  final List<CalendarEvent> events;
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final ValueChanged<CalendarEvent> onOpen;

  @override
  State<_EventsItem> createState() => _EventsItemState();
}

class _EventsItemState extends State<_EventsItem> {
  late int _index = widget.initialIndex;

  void _select(int index) {
    setState(() => _index = index);
    widget.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    // Un evento pudo terminar: el índice queda dentro.
    if (_index >= events.length) {
      _index = events.isEmpty ? 0 : events.length - 1;
    }

    return _HomeWidgetItem(
      focusNode: widget.focusNode,
      onKeyLeft: widget.onKeyLeft,
      onKeyUp: widget.onKeyUp,
      onKeyDown: widget.onKeyDown,
      onLeft: () {
        if (_index == 0) return false;
        _select(_index - 1);
        return true;
      },
      onRight: () {
        if (_index >= events.length - 1) return false;
        _select(_index + 1);
        return true;
      },
      onPress: () {
        if (events.isNotEmpty) widget.onOpen(events[_index]);
      },
      builder: (isFocused) => HomeEventsCard(
        events: events,
        selectedIndex: _index,
        isFocused: isFocused,
      ),
    );
  }
}

/// Tarjetas del Inicio (el orden en pantalla lo arma [_visibleWidgets]).
enum _HomeWidget {
  hero,
  weather,
  events,
  continueWatching,
  recommendations,
  discounts,
  friends,
  friendRequests,
  watchlistBig,
  trailers,
  arcade,
}

/// Ítem enfocable de la lista del Inicio: maneja las flechas y avisa al
/// [builder] si tiene el foco.
class _HomeWidgetItem extends StatefulWidget {
  const _HomeWidgetItem({
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.builder,
    this.onPress,
    this.onLeft,
    this.onRight,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final Widget Function(bool isFocused) builder;

  /// OK sobre el widget.
  final VoidCallback? onPress;

  /// ←/→ dentro del widget (p. ej. elegir un evento). Devuelven si lo
  /// usaron; si ← no se usa, sale al rail.
  final bool Function()? onLeft;
  final bool Function()? onRight;

  @override
  State<_HomeWidgetItem> createState() => _HomeWidgetItemState();
}

class _HomeWidgetItemState extends State<_HomeWidgetItem> {
  late bool _isFocused = widget.focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (widget.onPress != null && TvKeyHandler.isActionKey(key)) {
          widget.onPress!();
          return KeyEventResult.handled;
        }
        return TvKeyHandler.handleDirectional(
          key: key,
          onLeft: () {
            if (widget.onLeft?.call() ?? false) return;
            widget.onKeyLeft();
          },
          onRight: widget.onRight == null ? null : () => widget.onRight!(),
          onUp: widget.onKeyUp,
          onDown: widget.onKeyDown,
        );
      },
      child: GestureDetector(
        onTap: widget.onPress,
        child: widget.builder(_isFocused),
      ),
    );
  }
}
