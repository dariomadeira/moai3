import 'dart:async';

import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/calendar/widgets/calendar_event_details_dialog.dart';
import 'package:moai3/features/games/arcade_launcher.dart';
import 'package:moai3/features/games/screens/arcade_games_screen.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/widgets/home_arcade_card.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/home/widgets/home_continue_card.dart';
import 'package:moai3/features/home/widgets/home_discounts_card.dart';
import 'package:moai3/features/home/widgets/home_events_card.dart';
import 'package:moai3/features/home/widgets/home_friends_card.dart';
import 'package:moai3/features/home/widgets/home_movie_list_card.dart';
// EN PAUSA (cielo del momento): import 'package:moai3/features/home/widgets/home_sky.dart';
import 'package:moai3/features/home/widgets/home_trailers_card.dart';
import 'package:moai3/features/home/widgets/home_watchlist_card.dart';
import 'package:moai3/features/home/widgets/home_weather_card.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/features/movies/movie_playback.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/services/movie_library.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
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

  /// Ir a Agenda › Suscripciones (botón del widget de eventos sin eventos).
  final VoidCallback? onOpenSubscriptions;

  /// Ir a Descuentos (tarjeta de descuentos): a un día o a Configurar.
  final void Function({int dayIndex, bool settings})? onOpenDiscounts;

  /// ROMs del Arcade: el widget de Arcade muestra la activa.
  final ArcadeRomManagerService romManager;

  const HomeDashboardArea({
    super.key,
    required this.onExitLeft,
    required this.romManager,
    this.onTuneChannel,
    this.onOpenSubscriptions,
    this.onOpenDiscounts,
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
  int _selectedIndex = 0;

  /// Evento elegido en el widget de eventos (←/→).
  int _eventIndex = 0;

  /// Acción elegida en el widget de Arcade (←/→).
  HomeArcadeAction _arcadeAction = HomeArcadeAction.start;
  Timer? _hourTimer;
  DateTime _now = DateTime.now();

  /// Cada widget ocupa el doble que un ítem de Ajustes (70): 132 de card + 8.
  /// Siempre se ven 4 tarjetas: cada una ocupa la cuarta parte del lugar
  /// (en el TV, unos 107 puntos), como mucho [_maxItemExtent].
  static const int _windowSize = 4;
  static const double _maxItemExtent = 140;

  @override
  void initState() {
    super.initState();
    _scheduleNextHour();
    // El widget de Arcade aparece/desaparece con el plugin y la ROM activa.
    ArcadePluginService.instance.addListener(_onArcadeChanged);
    widget.romManager.addListener(_onArcadeChanged);
    MovieWatchlistService.instance.addListener(_onWatchlistChanged);
    unawaited(_loadContinue());
  }

  void _onWatchlistChanged() {
    if (mounted) setState(() {});
  }

  void _onArcadeChanged() {
    if (mounted) setState(() {});
  }

  /// Widgets visibles, en orden. "Seguir viendo", "Interesantes" y
  /// "Adelantos" sólo si Películas está en el rail ([moviesVisible]); "Seguir
  /// viendo" y "Adelantos" además si tienen algo. Arcade sólo con el plugin
  /// instalado y una ROM activa lista para jugar.
  List<_HomeWidget> _visibleWidgets({
    required bool moviesVisible,
    required bool hasTrailers,
    required bool hasEventsToday,
    required bool watchPartyEnabled,
  }) => [
    _HomeWidget.weather,
    // Sin nada por ver hoy (en curso o por empezar), no ocupa lugar.
    if (hasEventsToday) _HomeWidget.events,
    _HomeWidget.discounts,
    // Amigos conectados y su canal: sólo con Miremos Juntos activado.
    if (watchPartyEnabled) _HomeWidget.friends,
    if (moviesVisible && _continue.isNotEmpty) _HomeWidget.continueWatching,
    if (moviesVisible) _HomeWidget.watchlist,
    if (moviesVisible && hasTrailers) _HomeWidget.trailers,
    if (ArcadePluginService.instance.isInstalled &&
        widget.romManager.activeRom != null)
      _HomeWidget.arcade,
  ];

  /// Refresca saludo y próximas horas del clima al cambiar la hora.
  void _scheduleNextHour() {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _hourTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleNextHour();
    });
  }

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
    if (!canInvite && _arcadeAction == HomeArcadeAction.invite) {
      _arcadeAction = HomeArcadeAction.start;
    }
    final watchPartyEnabled = context.select(
      (WatchPartyProvider? w) => w?.enabled ?? false,
    );
    // Ajustes › Películas y series puede apagar la tarjeta de adelantos.
    final showTrailers = context.select(
      (TvSettingsProvider? s) => s?.showHomeTrailers ?? true,
    );
    final moviesVisible = context.select(
      (FeaturedMoviesProvider? p) =>
          p?.isSectionAvailable(FeaturedMoviesProvider.sectionMovies) ?? false,
    );
    final trailers = context.select(
      (FeaturedMoviesProvider? p) =>
          p?.trailersFor(FeaturedMoviesProvider.sectionMovies) ??
          const <MovieItem>[],
    );
    // EN PAUSA (cielo del momento, ver más abajo): el cielo seguía al tiempo.
    // final weatherCode = context.select<WeatherProvider?, int?>(
    //   (w) => w?.weather?.conditionCode,
    // );
    if (moviesVisible) _ensureMoviesLoaded();

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
            if (hasFocus) _listKey.currentState?.ensureVisible(_selectedIndex);
          },
          child: Stack(
            children: [
              // EN PAUSA: "cielo del momento", la foto del cielo de esta hora
              // y este tiempo detrás del saludo y las tarjetas
              // (HomeSkyBackdrop, fotos en assets/images/home_sky/). Se sacó
              // hasta revisarla: en tema claro las fotos se veían lavadas y
              // en oscuro "noche con lluvia" y "tormenta" molestaban. Para
              // volver: descomentar esto, `weatherCode` arriba y la carpeta
              // en pubspec.yaml.
              // Positioned.fill(
              //   child: ClipRRect(
              //     borderRadius: const BorderRadius.only(
              //       topRight: Radius.circular(15),
              //       bottomRight: Radius.circular(15),
              //     ),
              //     child: HomeSkyBackdrop(time: _now, weatherCode: weatherCode),
              //   ),
              // ),
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
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: HomeClock(),
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
                                items: _visibleWidgets(
                                  hasEventsToday: hasEventsToday,
                                  watchPartyEnabled: watchPartyEnabled,
                                  moviesVisible: moviesVisible,
                                  hasTrailers:
                                      showTrailers && trailers.isNotEmpty,
                                ),
                                windowSize: _windowSize,
                                itemExtent: itemExtent,
                                showScrollDots: true,
                                initialGlobalIndex: _selectedIndex,
                                onFocusedGlobalIndex: (idx) =>
                                    _selectedIndex = idx,
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
                                      child: _buildItem(
                                        item,
                                        focusNode,
                                        onKeyUp,
                                        onKeyDown,
                                        trailers,
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

  /// Cada tarjeta con su manejo de teclas.
  Widget _buildItem(
    _HomeWidget item,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
    List<MovieItem> trailers,
  ) {
    switch (item) {
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
          selectedIndex: _continueIndex,
          onSelect: (i) => setState(() => _continueIndex = i),
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
      case _HomeWidget.watchlist:
        final movies = MovieWatchlistService.instance.movies;
        return _MovieListItem(
          focusNode: focusNode,
          movies: movies,
          selectedIndex: _watchlistIndex,
          onSelect: (i) => setState(() => _watchlistIndex = i),
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openMovie,
          onRemove: _confirmRemoveFromWatchlist,
          onClearAll: _confirmClearWatchlist,
          buildCard: (selected, focused) => HomeWatchlistCard(
            movies: movies,
            selectedIndex: selected,
            isFocused: focused,
          ),
        );
      case _HomeWidget.trailers:
        return _TrailersItem(
          focusNode: focusNode,
          trailers: trailers,
          selectedIndex: _trailerIndex,
          onSelect: (i) => setState(() => _trailerIndex = i),
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onOpen: _openMovie,
        );
      case _HomeWidget.weather:
      case _HomeWidget.arcade:
        final arcade = item == _HomeWidget.arcade;
        return _HomeWidgetItem(
          focusNode: focusNode,
          onKeyLeft: widget.onExitLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          onPress: arcade ? _runArcadeAction : null,
          onLeft: arcade ? () => _moveArcadeAction(-1) : null,
          onRight: arcade ? () => _moveArcadeAction(1) : null,
          builder: (isFocused) => _buildWidget(item, isFocused),
        );
    }
  }

  Widget _buildWidget(_HomeWidget item, bool isFocused) {
    switch (item) {
      case _HomeWidget.weather:
        final weatherProvider = context.watch<WeatherProvider?>();
        final weather = weatherProvider?.weather;
        if (weather == null) {
          return const MoaiGlass(
            borderRadius: HomeWeatherCard.radius,
            elevated: false,
            child: SizedBox.expand(),
          );
        }
        return HomeWeatherCard(
          weather: weather,
          now: _now,
          isFocused: isFocused,
          place: weatherProvider?.placeName,
        );
      case _HomeWidget.events:
        // Lo arma [_buildEventsItem], que además maneja ←/→ y OK.
        return const SizedBox.shrink();
      case _HomeWidget.continueWatching:
      case _HomeWidget.watchlist:
      case _HomeWidget.discounts:
      case _HomeWidget.friends:
        // Las arman sus ítems, que además manejan ←/→, OK y mantener OK.
        return const SizedBox.shrink();
      case _HomeWidget.trailers:
        // Lo arma [_TrailersItem], que además maneja ←/→ y OK.
        return const SizedBox.shrink();
      case _HomeWidget.arcade:
        final rom = widget.romManager.activeRom;
        if (rom == null) return const SizedBox.shrink();
        return HomeArcadeCard(
          romName: widget.romManager.displayNameOf(rom),
          details: [
            rom.company,
            rom.year,
          ].where((s) => s.trim().isNotEmpty).join('  ·  '),
          selectedAction: _arcadeAction,
          isFocused: isFocused,
          canInvite: _canInvite,
        );
    }
  }

  /// ←/→ en el widget de Arcade. Devuelve si se movió (← desde la primera
  /// acción sale al rail).
  /// Hay algún amigo conectado: la tarjeta de Arcade ofrece "Invitar".
  bool get _canInvite =>
      context.read<WatchPartyProvider?>()?.hasOnlineFriends ?? false;

  bool _moveArcadeAction(int delta) {
    final next = _arcadeAction.index + delta;
    // Sin amigos conectados, "Invitar" no está.
    final count = HomeArcadeAction.values.length - (_canInvite ? 0 : 1);
    if (next < 0 || next >= count) return false;
    setState(() => _arcadeAction = HomeArcadeAction.values[next]);
    return true;
  }

  /// OK en el widget de Arcade: como "Iniciar juego", "Seleccionar juego" y
  /// "Jugar juntos" del área de Arcade.
  void _runArcadeAction() {
    switch (_arcadeAction) {
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

  /// Widget de eventos de hoy: ←/→ eligen el evento y OK abre su detalle;
  /// sin eventos, OK lleva a Suscripciones.
  Widget _buildEventsItem(
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) {
    final calendar = context.watch<CalendarProvider>();
    final hasSubscriptions = calendar.subscriptions.any((s) => s.isSubscribed);
    // Sólo lo que se puede ver: en curso o por empezar (los terminados, no).
    final events = calendar
        .getEventsForDay(ArgentinaTime.now())
        .where((e) => e.status != CalendarEventStatus.finished)
        .toList();
    if (_eventIndex >= events.length) {
      _eventIndex = events.isEmpty ? 0 : events.length - 1;
    }

    return _HomeWidgetItem(
      focusNode: focusNode,
      onKeyLeft: widget.onExitLeft,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      onLeft: () {
        if (_eventIndex == 0) return false;
        setState(() => _eventIndex--);
        return true;
      },
      onRight: () {
        if (_eventIndex >= events.length - 1) return false;
        setState(() => _eventIndex++);
        return true;
      },
      onPress: () {
        if (events.isEmpty) {
          // El botón a Suscripciones sólo aparece sin ninguna suscripción.
          if (!hasSubscriptions) widget.onOpenSubscriptions?.call();
          return;
        }
        showCalendarEventDetails(
          context,
          events[_eventIndex],
          onTuneChannel: widget.onTuneChannel,
        );
      },
      builder: (isFocused) => HomeEventsCard(
        events: events,
        selectedIndex: _eventIndex,
        hasSubscriptions: hasSubscriptions,
        isFocused: isFocused,
      ),
    );
  }
}

/// Widgets de información del Inicio, en el orden de la lista.
enum _HomeWidget {
  weather,
  events,
  discounts,
  friends,
  continueWatching,
  watchlist,
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
