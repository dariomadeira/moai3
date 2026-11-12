part of 'home_dashboard_area.dart';

/// "Seguir series" del Inicio: su estado, abrir el detalle de una serie en
/// el capítulo para seguir y las confirmaciones. Lo que se muestra lo decide
/// [SeriesContinueService].
mixin _HomeSeriesCards on HomeAreaState<HomeDashboardArea>, _HomeMovieCards {
  /// Elegido en "Seguir series": una serie, o
  /// [HomeSeriesContinueCard.clearAllIndex] para "Quitar todas".
  int _seriesContinueIndex = 0;

  /// Las series que se están viendo, la última primero.
  List<SeriesContinueItem> _seriesContinue = const [];

  /// Ya se buscaron capítulos nuevos en este arranque ([SeriesNews]).
  bool _newsChecked = false;

  /// Con Series cargado (ya hay sesión en el portal), una vez por arranque:
  /// [SeriesNews.check] sólo pregunta si pasó un día. Lo que aparezca avisa
  /// solo ([SeriesContinueService.changes]) y la tarjeta se relee.
  void _checkSeriesNews() {
    if (_newsChecked) return;
    _newsChecked = true;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(SeriesNews.check()),
    );
  }

  Future<void> _loadSeriesContinue() async {
    final items = await SeriesContinueService.items();
    if (mounted) setState(() => _seriesContinue = items);
  }

  /// Cambió lo visto de alguna serie ([SeriesContinueService.changes]): se
  /// vuelve a leer, salvo detrás del reproductor (ahí se guarda cada 10 s);
  /// al volver del detalle, [_openSeries] la relee.
  void _onSeriesChanged() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    unawaited(_loadSeriesContinue());
  }

  SeriesContinueItem? _seriesItemOf(MovieItem movie) => _seriesContinue
      .where((i) => i.entry.seriesKey == movie.contentId)
      .firstOrNull;

  /// OK en una serie: abre su detalle en la temporada del capítulo para
  /// seguir y con el foco en él (de ahí se reproduce como siempre).
  Future<void> _openSeries(MovieItem movie) async {
    final item = _seriesItemOf(movie);
    if (item == null) return;
    final episode = item.episode;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeriesDetailScreen(
          series: MovieItem(
            contentId: episode.seasonId,
            name: '${item.entry.title} T${episode.seasonNumber}',
            poster: item.entry.poster,
            backdrops: item.entry.backdrops,
            programType: 'teleplay',
          ),
          initialEpisodeId: episode.episodeId.isEmpty
              ? null
              : episode.episodeId,
          initialEpisodeNumber: episode.episodeNumber,
        ),
      ),
    );
    await _loadSeriesContinue();
  }

  /// Mantener OK en una serie: confirma y la quita de la tarjeta (lo visto
  /// queda marcado).
  Future<void> _confirmRemoveSeries(MovieItem movie) async {
    final item = _seriesItemOf(movie);
    if (item == null) return;
    final confirmed = await _confirm(
      icon: MoaiIcons.delete,
      title: LocaleKeys.home_series_continue_remove_title.tr(),
      subtitle: LocaleKeys.home_series_continue_remove_desc.tr(
        namedArgs: {'name': item.entry.title},
      ),
      confirmLabel: LocaleKeys.home_series_continue_remove.tr(),
    );
    if (!confirmed) return;
    await SeriesContinueService.remove(item.entry.seriesKey);
    await _loadSeriesContinue();
  }

  /// "Quitar todas": confirma y vacía la tarjeta.
  Future<void> _confirmClearSeries() async {
    final confirmed = await _confirm(
      icon: MoaiIcons.delete,
      title: LocaleKeys.home_series_continue_clear_title.tr(),
      subtitle: LocaleKeys.home_series_continue_clear_desc.tr(),
      confirmLabel: LocaleKeys.home_series_continue_clear.tr(),
    );
    if (!confirmed) return;
    await SeriesContinueService.clear();
    _seriesContinueIndex = 0;
    await _loadSeriesContinue();
  }

  /// Elegido en "Marcadas" de series: una serie, o
  /// [HomeSeriesWatchlistCard.clearAllIndex] para "Desmarcar todas".
  int _seriesWatchlistIndex = 0;

  /// Como [_onWatchlistChanged]: el Inicio entero sólo si la tarjeta
  /// aparece o se va.
  bool _hadSeriesWatchlist = SeriesWatchlistService.instance.items.isNotEmpty;

  void _onSeriesWatchlistChanged() {
    final has = SeriesWatchlistService.instance.items.isNotEmpty;
    if (has == _hadSeriesWatchlist) return;
    _hadSeriesWatchlist = has;
    if (mounted) setState(() {});
  }

  /// OK en una serie marcada o recomendada: su detalle. Al volver, lo que
  /// cambió (empezada: sale de Marcadas y pasa a "Seguir series"; votada:
  /// sale de Recomendadas).
  Future<void> _openSeriesDetail(MovieItem series) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
    );
    _refreshRecommendations();
    await _loadSeriesContinue();
  }

  /// Mantener OK en una serie marcada: confirma y la desmarca.
  Future<void> _confirmUnmarkSeries(MovieItem series) async {
    final watchlist = SeriesWatchlistService.instance;
    final entry = watchlist.entries
        .where((e) => e.item.contentId == series.contentId)
        .firstOrNull;
    if (entry == null) return;
    final confirmed = await _confirm(
      icon: MoaiIcons.vodWatchlistRemove,
      title: LocaleKeys.home_series_watchlist_remove_title.tr(),
      subtitle: LocaleKeys.home_series_watchlist_remove_desc.tr(
        namedArgs: {'name': series.name},
      ),
      confirmLabel: LocaleKeys.home_watchlist_remove.tr(),
    );
    if (confirmed) await watchlist.remove(entry.seasonIds);
  }

  /// "Desmarcar todas": confirma y vacía la lista.
  Future<void> _confirmClearMarkedSeries() async {
    final confirmed = await _confirm(
      icon: MoaiIcons.vodWatchlistRemove,
      title: LocaleKeys.home_watchlist_clear_title.tr(),
      subtitle: LocaleKeys.home_series_watchlist_clear_desc.tr(),
      confirmLabel: LocaleKeys.home_watchlist_remove_all.tr(),
    );
    if (!confirmed) return;
    await SeriesWatchlistService.instance.clear();
    _seriesWatchlistIndex = 0;
  }

  /// "Recomendadas" de series: lo elegido y lo que recomendaron los amigos.
  int _seriesRecommendationIndex = 0;
  List<FriendRecommendation> _seriesRecommendations = const [];

  /// Mantener OK sobre una serie recomendada: sale sólo de este TV.
  Future<void> _confirmDismissSeriesRecommendation(MovieItem series) async {
    final recommendations = context.read<SeriesRecommendationsProvider>();
    final confirmed = await _confirm(
      icon: MoaiIcons.delete,
      title: LocaleKeys.home_recommendations_remove_title.tr(),
      subtitle: LocaleKeys.home_recommendations_remove_desc.tr(
        namedArgs: {'name': series.name},
      ),
      confirmLabel: LocaleKeys.home_recommendations_remove.tr(),
    );
    if (confirmed) await recommendations.dismiss(series.contentId);
  }

  Future<void> _confirmDismissAllSeriesRecommendations() async {
    final recommendations = context.read<SeriesRecommendationsProvider>();
    final confirmed = await _confirm(
      icon: MoaiIcons.delete,
      title: LocaleKeys.home_recommendations_clear_title.tr(),
      subtitle: LocaleKeys.home_recommendations_clear_desc.tr(),
      confirmLabel: LocaleKeys.home_recommendations_clear.tr(),
    );
    if (!confirmed) return;
    await recommendations.dismissAll();
    _seriesRecommendationIndex = 0;
  }
}
