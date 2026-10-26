part of 'home_dashboard_area.dart';

/// Las tarjetas de películas del Inicio ("Seguir viendo", "Interesantes",
/// "Adelantos"): su estado, abrir y retomar películas y las confirmaciones.
/// Las reglas (qué sale de dónde) son de [MovieLibrary].
mixin _HomeMovieCards on HomeAreaState<HomeDashboardArea> {
  /// Elegido en "Interesantes" (←/→): una película, o
  /// [HomeWatchlistCard.clearAllIndex] para el botón "Quitar todas".
  int _watchlistIndex = 0;

  /// Adelanto elegido en "Adelantos" (←/→).
  int _trailerIndex = 0;

  /// Elegido en "Seguir viendo": una película, o
  /// [HomeContinueCard.markAllIndex] para "Marcar todo como visto".
  int _continueIndex = 0;

  /// "Seguir viendo": las películas empezadas (la última vista primero) y
  /// cuánto se vio de cada una.
  List<MovieItem> _continue = const [];
  Map<String, double> _continueWatched = const {};

  /// Ya se pidió cargar Películas para tener los adelantos.
  bool _moviesLoadRequested = false;

  /// Arma "Seguir viendo" ([MovieLibrary.continueWatching]). Los progresos
  /// guardados antes de que llevaran la película se buscan en el catálogo
  /// cargado.
  Future<void> _loadContinue() async {
    final catalog = context.read<FeaturedMoviesProvider?>();
    MovieItem? fromCatalog(String id) {
      if (catalog == null) return null;
      for (final section in const [
        FeaturedMoviesProvider.sectionMovies,
        FeaturedMoviesProvider.sectionFeatured,
      ]) {
        for (final movie in catalog.itemsFor(section)) {
          if (movie.contentId == id) return movie;
        }
      }
      return null;
    }

    final entries = await MovieLibrary.continueWatching(lookup: fromCatalog);
    if (!mounted) return;
    setState(() {
      _continue = [for (final e in entries) e.movie];
      _continueWatched = {
        for (final e in entries) e.movie.contentId: e.watched,
      };
    });
  }

  /// Después de ver algo: "Seguir viendo" cambia (e Interesantes, que
  /// avisa sola al quitarle una).
  Future<void> _reloadProgress() => _loadContinue();

  /// Carga Películas en segundo plano para tener los adelantos sin entrar a
  /// la sección (que si no se carga recién al abrirla).
  void _ensureMoviesLoaded() {
    if (_moviesLoadRequested) return;
    _moviesLoadRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final movies = context.read<FeaturedMoviesProvider?>();
      const section = FeaturedMoviesProvider.sectionMovies;
      if (movies == null ||
          movies.loadedOnceFor(section) ||
          movies.isLoadingFor(section)) {
        return;
      }
      // Con el catálogo, "Seguir viendo" encuentra progresos viejos que no
      // guardaban la película.
      unawaited(movies.loadSection(section).then((_) => _loadContinue()));
    });
  }

  /// OK en "Interesantes" o "Adelantos": el detalle de la película o del
  /// adelanto.
  Future<void> _openMovie(MovieItem movie) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)));
    // Pudo verla un rato (o entera): las barras y "Seguir viendo" cambian.
    await _reloadProgress();
  }

  /// Película de "Seguir viendo" que se está abriendo: mientras se pide el
  /// video (unos segundos) muestra que carga y otro OK no abre otra.
  String? _resumingId;

  /// OK en "Seguir viendo": la retoma directo donde quedó (sin el detalle).
  Future<void> _resumeMovie(MovieItem movie) async {
    if (_resumingId != null) return;
    setState(() => _resumingId = movie.contentId);
    try {
      final progress = await MovieProgressService.getProgress(movie.contentId);
      if (!mounted) return;
      await playMovie(
        context,
        movie,
        startAt: (progress?.canResume ?? false)
            ? progress!.positionSeconds
            : null,
      );
    } finally {
      if (mounted) setState(() => _resumingId = null);
    }
    await _reloadProgress();
  }

  /// Mantener OK en "Seguir viendo": confirma y la marca como vista aunque
  /// haya quedado a la mitad (sale de "Seguir viendo" y de Interesantes).
  Future<void> _confirmMarkWatched(MovieItem movie) async {
    final confirmed = await _confirm(
      icon: MoaiIcons.vodWatched,
      title: LocaleKeys.home_continue_mark_title.tr(),
      subtitle: LocaleKeys.home_continue_mark_desc.tr(
        namedArgs: {'name': movie.name},
      ),
      confirmLabel: LocaleKeys.home_continue_mark.tr(),
    );
    if (!confirmed) return;
    await _markWatched([movie]);
  }

  /// "Marcar todo como visto": confirma y las marca a todas.
  Future<void> _confirmMarkAllWatched() async {
    final confirmed = await _confirm(
      icon: MoaiIcons.vodWatched,
      title: LocaleKeys.home_continue_mark_all_title.tr(),
      subtitle: LocaleKeys.home_continue_mark_all_desc.tr(),
      // Corto: con Cancelar al lado, el rótulo largo no entra.
      confirmLabel: LocaleKeys.home_continue_mark_all_confirm.tr(),
    );
    if (!confirmed) return;
    await _markWatched(_continue);
    if (mounted) setState(() => _continueIndex = 0);
  }

  Future<void> _markWatched(List<MovieItem> movies) async {
    await MovieLibrary.markWatched(movies);
    await _reloadProgress();
  }

  /// Confirmación con Cancelar (con el foco) y la acción.
  Future<bool> _confirm({
    required IconData icon,
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) async {
    final cancelFocus = FocusNode(debugLabel: 'confirm_cancel');
    final okFocus = FocusNode(debugLabel: 'confirm_ok');
    final result = await showTvGeneralDialog<bool>(
      context: context,
      barrierLabel: 'Confirm',
      builder: (dialogContext) => TvDialog(
        icon: icon,
        title: title,
        subtitle: subtitle,
        actions: [
          TvDialogButton(
            label: LocaleKeys.common_cancel.tr(),
            focusNode: cancelFocus,
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            onKeyRight: okFocus.requestFocus,
          ),
          TvDialogButton(
            label: confirmLabel,
            variant: TvDialogButtonVariant.primary,
            focusNode: okFocus,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            onKeyLeft: cancelFocus.requestFocus,
          ),
        ],
      ),
    );
    cancelFocus.dispose();
    okFocus.dispose();
    return result == true;
  }

  /// Mantener OK sobre una película de "Interesantes": confirma y la quita.
  /// Cancelar arranca con el foco.
  Future<void> _confirmRemoveFromWatchlist(MovieItem movie) async {
    final cancelFocus = FocusNode(debugLabel: 'watchlist_remove_cancel');
    final removeFocus = FocusNode(debugLabel: 'watchlist_remove_confirm');
    final confirmed = await showTvGeneralDialog<bool>(
      context: context,
      barrierLabel: 'RemoveFromWatchlist',
      builder: (dialogContext) => TvDialog(
        icon: MoaiIcons.vodWatchlist,
        title: LocaleKeys.home_watchlist_remove_title.tr(),
        subtitle: LocaleKeys.home_watchlist_remove_desc.tr(
          namedArgs: {'name': movie.name},
        ),
        actions: [
          TvDialogButton(
            label: LocaleKeys.common_cancel.tr(),
            focusNode: cancelFocus,
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            onKeyRight: removeFocus.requestFocus,
          ),
          TvDialogButton(
            label: LocaleKeys.home_watchlist_remove.tr(),
            variant: TvDialogButtonVariant.destructive,
            focusNode: removeFocus,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            onKeyLeft: cancelFocus.requestFocus,
          ),
        ],
      ),
    );
    cancelFocus.dispose();
    removeFocus.dispose();
    if (confirmed == true) {
      await MovieWatchlistService.instance.remove(movie.contentId);
    }
  }

  /// Botón "Quitar todas" de "Interesantes": confirma y vacía la lista.
  /// Cancelar arranca con el foco.
  Future<void> _confirmClearWatchlist() async {
    final cancelFocus = FocusNode(debugLabel: 'watchlist_clear_cancel');
    final clearFocus = FocusNode(debugLabel: 'watchlist_clear_confirm');
    final confirmed = await showTvGeneralDialog<bool>(
      context: context,
      barrierLabel: 'ClearWatchlist',
      builder: (dialogContext) => TvDialog(
        icon: MoaiIcons.delete,
        title: LocaleKeys.home_watchlist_clear_title.tr(),
        subtitle: LocaleKeys.home_watchlist_clear_desc.tr(),
        actions: [
          TvDialogButton(
            label: LocaleKeys.common_cancel.tr(),
            focusNode: cancelFocus,
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            onKeyRight: clearFocus.requestFocus,
          ),
          TvDialogButton(
            label: LocaleKeys.home_watchlist_remove_all.tr(),
            variant: TvDialogButtonVariant.destructive,
            focusNode: clearFocus,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            onKeyLeft: cancelFocus.requestFocus,
          ),
        ],
      ),
    );
    cancelFocus.dispose();
    clearFocus.dispose();
    if (confirmed == true) {
      await MovieWatchlistService.instance.clear();
      if (mounted) setState(() => _watchlistIndex = 0);
    }
  }
}

/// Tarjeta de películas con botón de acción ("Interesantes", "Seguir
/// viendo"): ←/→ recorren las películas y, a la izquierda de la primera, el
/// botón. OK sobre una película llama a [onOpen] y mantener OK a [onRemove];
/// OK sobre el botón, a [onClearAll]. Sin películas sólo se sale.
class _MovieListItem extends StatefulWidget {
  const _MovieListItem({
    required this.focusNode,
    required this.movies,
    required this.selectedIndex,
    required this.onSelect,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onOpen,
    required this.onRemove,
    required this.onClearAll,
    required this.buildCard,
  });

  final FocusNode focusNode;
  final List<MovieItem> movies;
  final int selectedIndex;

  /// La tarjeta, con la selección ya ajustada y si tiene el foco.
  final Widget Function(int selectedIndex, bool isFocused) buildCard;
  final ValueChanged<int> onSelect;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final ValueChanged<MovieItem> onOpen;
  final ValueChanged<MovieItem> onRemove;
  final VoidCallback onClearAll;

  @override
  State<_MovieListItem> createState() => _MovieListItemState();
}

class _MovieListItemState extends State<_MovieListItem> {
  static const _clearAll = HomeMovieListCard.actionIndex;

  late bool _isFocused = widget.focusNode.hasFocus;

  /// La lista pudo achicarse (se quitó la última): el índice queda dentro.
  int get _index => widget.movies.isEmpty
      ? 0
      : widget.selectedIndex.clamp(_clearAll, widget.movies.length - 1);

  bool get _onMovie => widget.movies.isNotEmpty && _index != _clearAll;

  void _press() {
    if (widget.movies.isEmpty) return;
    if (_index == _clearAll) {
      widget.onClearAll();
    } else {
      widget.onOpen(widget.movies[_index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvPressDetector(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onPress: _press,
      // Sólo sobre una película; en el botón OK alcanza.
      onLongPress: _onMovie
          ? () => widget.onRemove(widget.movies[_index])
          : null,
      onLeft: () {
        if (widget.movies.isNotEmpty && _index > _clearAll) {
          widget.onSelect(_index - 1);
        } else {
          widget.onKeyLeft();
        }
        return true;
      },
      onRight: () {
        if (_index < widget.movies.length - 1) widget.onSelect(_index + 1);
        return true;
      },
      onUp: widget.onKeyUp,
      onDown: widget.onKeyDown,
      child: GestureDetector(
        onTap: _press,
        child: widget.buildCard(_index, _isFocused),
      ),
    );
  }
}

/// "Adelantos": ←/→ recorren los adelantos y OK abre el detalle del elegido.
/// ← desde el primero sale al rail.
class _TrailersItem extends StatefulWidget {
  const _TrailersItem({
    required this.focusNode,
    required this.trailers,
    required this.selectedIndex,
    required this.onSelect,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    required this.onOpen,
  });

  final FocusNode focusNode;
  final List<MovieItem> trailers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final ValueChanged<MovieItem> onOpen;

  @override
  State<_TrailersItem> createState() => _TrailersItemState();
}

class _TrailersItemState extends State<_TrailersItem> {
  late bool _isFocused = widget.focusNode.hasFocus;

  /// El catálogo pudo cambiar: el índice queda dentro.
  int get _index => widget.trailers.isEmpty
      ? 0
      : widget.selectedIndex.clamp(0, widget.trailers.length - 1);

  void _press() {
    if (widget.trailers.isEmpty) return;
    widget.onOpen(widget.trailers[_index]);
  }

  @override
  Widget build(BuildContext context) {
    return TvPressDetector(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onPress: _press,
      onLeft: () {
        if (_index > 0) {
          widget.onSelect(_index - 1);
        } else {
          widget.onKeyLeft();
        }
        return true;
      },
      onRight: () {
        if (_index < widget.trailers.length - 1) widget.onSelect(_index + 1);
        return true;
      },
      onUp: widget.onKeyUp,
      onDown: widget.onKeyDown,
      child: GestureDetector(
        onTap: _press,
        child: HomeTrailersCard(
          trailers: widget.trailers,
          selectedIndex: _index,
          isFocused: _isFocused,
        ),
      ),
    );
  }
}
