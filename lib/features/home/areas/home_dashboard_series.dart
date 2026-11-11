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
}
