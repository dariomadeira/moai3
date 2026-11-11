import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/movies/widgets/movie_detail_parts.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:provider/provider.dart';

/// Detalle de una serie: la ficha como la de una película, la lista de
/// temporadas (si hay más de una) y los capítulos de la elegida, como
/// cuadrados con su número. Todavía no reproduce ni marca nada.
///
/// En el portal cada temporada es un ítem propio ([series] es la que se
/// abrió); el detalle de cada una se pide al elegirla.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series, this.fetchSeason});

  final MovieItem series;

  /// Pide el detalle de una temporada; por defecto
  /// [MoiamovApiService.fetchSeriesSeason]. Los tests lo reemplazan.
  final Future<SeriesSeasonDetail?> Function(String contentId)? fetchSeason;

  @override
  State<SeriesDetailScreen> createState() => SeriesDetailScreenState();
}

class SeriesDetailScreenState extends State<SeriesDetailScreen> {
  final FocusNode _backFocus = FocusNode(debugLabel: 'series_detail_back');
  final FocusNode _seasonsFocus = FocusNode(
    debugLabel: 'series_detail_seasons',
  );
  final FocusNode _episodesFocus = FocusNode(
    debugLabel: 'series_detail_episodes',
  );

  /// Los capítulos van en una fila, como las del Inicio: [episodeHeight] de
  /// alto y por lo menos [episodeMinWidth] de ancho; entran los que caben y
  /// se estiran hasta llenarla, así queda pareja entre las flechas.
  static const double episodeHeight = 52;
  static const double episodeMinWidth = 64;
  static const double episodeGap = 10;

  /// Alto de las píldoras de las temporadas (su fila usa la misma medida que
  /// la de los capítulos).
  static const double seasonHeight = 36;

  /// La foto horizontal a la derecha de la ficha. Escondida por ahora, para
  /// ver cómo queda sin ella.
  static const bool showPreview = false;

  /// Cuánto espera, al pasar de temporada, antes de pedirla: así recorrer
  /// la lista no pide todas.
  static const Duration seasonLoadDelay = Duration(milliseconds: 300);

  /// Detalle de cada temporada ya pedida, por `contentId`.
  final Map<String, SeriesSeasonDetail> _details = {};
  final Set<String> _failed = {};
  final Set<String> _loading = {};

  /// Las temporadas de la serie: llegan con el primer detalle.
  List<SeriesSeason> _seasons = const [];

  /// La temporada que se ve (su `contentId`).
  late String _seasonId = widget.series.contentId;
  int _episode = 0;

  Timer? _seasonTimer;

  @visibleForTesting
  String get debugSeasonId => _seasonId;

  @visibleForTesting
  int get debugEpisodeIndex => _episode;

  SeriesSeasonDetail? get _detail => _details[_seasonId];

  /// La ficha: la de la temporada elegida; mientras carga, la última que
  /// se vio (o la del catálogo), así no salta.
  late MovieItem _info = widget.series;

  int get _seasonIndex => _seasons.indexWhere((s) => s.contentId == _seasonId);

  bool get _hasSeasonList => _seasons.length > 1;

  List<SeriesEpisode> get _episodes => _detail?.episodes ?? const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load(_seasonId));
    _focusEpisodesWhenBuilt();
    for (final node in [_seasonsFocus, _episodesFocus]) {
      node.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _seasonTimer?.cancel();
    _backFocus.dispose();
    _seasonsFocus.dispose();
    _episodesFocus.dispose();
    super.dispose();
  }

  /// Al abrir, el foco en los capítulos. El panel no deja enfocar nada
  /// adentro hasta terminar de abrirse: se reintenta cuadro a cuadro (como
  /// mucho [_focusAttempts]).
  void _focusEpisodesWhenBuilt([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _episodesFocus.hasFocus) return;
      // Ya lo movió el usuario.
      if (_backFocus.hasFocus || _seasonsFocus.hasFocus) return;
      _episodesFocus.requestFocus();
      if (attempt < _focusAttempts) {
        _focusEpisodesWhenBuilt(attempt + 1);
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  static const int _focusAttempts = 60;

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load(String contentId) async {
    if (_details.containsKey(contentId) || !_loading.add(contentId)) return;
    _failed.remove(contentId);
    if (mounted) setState(() {});
    final fetch =
        widget.fetchSeason ?? MoiamovApiService.instance.fetchSeriesSeason;
    SeriesSeasonDetail? detail;
    try {
      detail = await fetch(contentId);
    } catch (_) {
      detail = null;
    }
    if (!mounted) return;
    setState(() {
      _loading.remove(contentId);
      if (detail == null) {
        _failed.add(contentId);
        return;
      }
      _details[contentId] = detail;
      if (_seasons.isEmpty || detail.seasons.length > _seasons.length) {
        _seasons = detail.seasons;
      }
      if (contentId != _seasonId) return;
      _info = detail.info;
      // A veces la que se abrió no está en la lista con su `contentId`: se
      // la reconoce por el número del nombre ("T13", "S13"), así queda
      // marcada y no se vuelve a pedir.
      if (_seasonIndex < 0) {
        final number = SeriesSeasonDetail.seasonNumber(detail.info);
        final same = _seasons.where((s) => s.number == number).firstOrNull;
        if (same != null) {
          _details[same.contentId] = detail;
          _seasonId = same.contentId;
        }
      }
    });
  }

  /// Pasa a otra temporada: la ficha y los capítulos son de ésa (se pide
  /// después de [seasonLoadDelay] si no está).
  void _selectSeason(int index) {
    final season = _seasons[index];
    setState(() {
      _seasonId = season.contentId;
      _episode = 0;
      if (_details[season.contentId] case final detail?) _info = detail.info;
    });
    _seasonTimer?.cancel();
    if (!_details.containsKey(season.contentId)) {
      _seasonTimer = Timer(seasonLoadDelay, () => _load(season.contentId));
    }
  }

  void _selectEpisode(int index) => setState(() => _episode = index);

  void _focusEpisodes() => _episodesFocus.requestFocus();

  void _focusTop() {
    if (_hasSeasonList) {
      _seasonsFocus.requestFocus();
    } else {
      _backFocus.requestFocus();
    }
  }

  KeyEventResult _onSeasonsKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final index = _seasonIndex;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (index > 0) {
        _selectSeason(index - 1);
      } else {
        _backFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      if (index < _seasons.length - 1) _selectSeason(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusEpisodes();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _backFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (TvKeyHandler.isActionKey(key)) {
      _focusEpisodes();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onEpisodesKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = _episodes.length;
    final index = _episode;
    // ←/→ recorren la fila (mantenidas, también); sólo un toque sale de ella.
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _selectEpisode(index - 1);
      } else if (event is KeyDownEvent) {
        _backFocus.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < count - 1) _selectEpisode(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (event is KeyDownEvent) _focusTop();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) return KeyEventResult.handled;
    if (TvKeyHandler.isActionKey(key)) {
      // Ver un capítulo todavía no; si los capítulos no cargaron, OK
      // vuelve a pedirlos.
      if (_failed.contains(_seasonId)) unawaited(_load(_seasonId));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );
    final tabTitle = LocaleKeys.series_detail_tab.tr();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        TvBackPill(
                          focusNode: _backFocus,
                          onKeyRight: _focusEpisodes,
                          onKeyDown: _focusEpisodes,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: TvAccordionRowPreview(
                        panelCount: 1,
                        activeIndex: 0,
                        colors: [scheme.surface.withValues(alpha: 0.85)],
                        titles: [tabTitle],
                        icons: const [MoaiIcons.vodPoster],
                        svgIcons: const [MoaiIcons.seriesSvg],
                        onPanelTap: (_) {},
                        buildExpandedContent: (index, title) =>
                            _content(context, scheme),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ColorScheme scheme) {
    final info = _info;
    final ambientUrl = info.ambientBackdrop;
    final image = info.stageImages.isNotEmpty
        ? info.stageImages.first
        : info.effectiveBackdrop;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(15),
        bottomRight: Radius.circular(15),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ambientUrl != null && ambientUrl.isNotEmpty)
            Positioned(
              top: 0,
              right: 0,
              width: movieDetailAmbientWidth,
              height: movieDetailAmbientHeight,
              child: IgnorePointer(
                child: MovieDetailAmbient(imageUrl: ambientUrl),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: _infoColumn(context, scheme)),
                      const SizedBox(width: 24),
                      // Sin la vista previa, su lugar queda libre (se ve la
                      // foto difuminada de arriba).
                      if (showPreview)
                        Expanded(
                          flex: 5,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _image(scheme, image),
                            ),
                          ),
                        )
                      else
                        const Spacer(flex: 5),
                    ],
                  ),
                ),
                if (_hasSeasonList) ...[
                  const SizedBox(height: 14),
                  _rowLabel(LocaleKeys.series_seasons_label.tr()),
                  _seasonList(),
                ],
                const SizedBox(height: 12),
                _rowLabel(LocaleKeys.series_episodes_label.tr()),
                _episodeGrid(context, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// La foto horizontal de la temporada, redondeada como la Hero.
  Widget _image(ColorScheme scheme, String? url) {
    final empty = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: MoaiSvgIcon(
          MoaiIcons.seriesSvg,
          size: MoaiIconSizes.xxl,
          color: scheme.outline,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: url == null || url.isEmpty
          ? empty
          : CachedNetworkImage(
              imageUrl: url,
              cacheManager: MovieImageCache.photos,
              fit: BoxFit.cover,
              memCacheWidth: 720,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => empty,
              errorWidget: (_, _, _) => empty,
            ),
    );
  }

  Widget _infoColumn(BuildContext context, ColorScheme scheme) {
    final info = _info;
    final title = SeriesSeasonDetail.seriesTitle(info.name);
    final alias = SeriesSeasonDetail.seriesTitle((info.alias ?? '').trim());
    final hasAlias =
        alias.isNotEmpty && alias.toLowerCase() != title.toLowerCase();
    final year = info.formattedYear;
    final genres = info.genreList;
    final scorePill = movieScorePill(context, info);
    final episodes = _detail?.episodes.length;
    final director = info.formattedDirector ?? '';

    TvMetaPill pill(IconData icon, String label) => TvMetaPill(
      dense: true,
      color: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
      icon: icon,
      label: label,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieDetailTitle(title),
        const SizedBox(height: 6),
        if (hasAlias) ...[MovieDetailAlias(alias), const SizedBox(height: 8)],
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ?scorePill,
            if (year != null && year.isNotEmpty)
              pill(MoaiIcons.vodReleaseDate, year),
            if (_hasSeasonList)
              TvMetaPill(
                dense: true,
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                svgIcon: MoaiIcons.seriesSeasonsSvg,
                label: LocaleKeys.series_seasons_count.tr(
                  namedArgs: {'count': '${_seasons.length}'},
                ),
              ),
            if (episodes != null && episodes > 0)
              pill(
                MoaiIcons.vodDuration,
                episodes == 1
                    ? LocaleKeys.series_episodes_one.tr()
                    : LocaleKeys.series_episodes_count.tr(
                        namedArgs: {'count': '$episodes'},
                      ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (genres.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final g in genres) TvMovieGenreChip(label: g)],
          ),
          const SizedBox(height: 12),
        ],
        if (director.isNotEmpty) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_director.tr(),
            value: director,
          ),
          const SizedBox(height: 4),
        ],
        if (info.formattedCast case final cast?) ...[
          MovieCreditRow(
            label: LocaleKeys.movies_cast.tr(),
            value: cast,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
        ],
        Expanded(child: MovieSynopsisBlock(description: info.description)),
      ],
    );
  }

  /// Separación entre una fila y sus puntos, y tamaño de cada punto (los de
  /// [TvWindowedRow]).
  static const double _dotsGap = 8;
  static const double _dotSize = 5;

  /// Más páginas que éstas no entran (One Piece tiene más de cien): se ven
  /// las de alrededor de la actual, y los puntos de las puntas, chicos,
  /// avisan que hay más (como [MoviePositionDots]).
  static const int _maxDots = 24;

  /// El rótulo de una fila ("Temporadas", "Capítulos"), en el gris de
  /// "Director:".
  Widget _rowLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: movieDetailLabelStyle(context)),
  );

  /// Cuántos recuadros entran en [width] y de qué ancho (ver [_edgeRow]).
  static (int, double) _fitIn(double width) {
    final fit = ((width + episodeGap) ~/ (episodeMinWidth + episodeGap)).clamp(
      1,
      1 << 20,
    );
    return (fit, (width - (fit - 1) * episodeGap) / fit);
  }

  /// Mientras llega la temporada: una línea de carga indeterminada, la de
  /// la pantalla de carga (acento sobre un riel tenue), en el medio del alto
  /// de la fila: no salta al llegar.
  Widget _loadingRow(ColorScheme scheme) => SizedBox(
    key: const ValueKey('episodes_loading'),
    height: episodeHeight,
    child: Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: LinearProgressIndicator(
          minHeight: 4,
          color: scheme.primary,
          backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
        ),
      ),
    ),
  );

  /// Una fila como las del Inicio ([HomeRowWindow]): se corre para que el
  /// elegido siempre se vea. Entran los que caben a [episodeMinWidth] y se
  /// estiran hasta llenar el ancho: como temporadas y capítulos usan la
  /// misma medida, T1 queda arriba del capítulo 1. Con menos, del mismo
  /// tamaño y desde la izquierda. Si no entran todos, abajo un punto por
  /// página, como en las listas ([TvWindowedRow], acá centrados).
  Widget _edgeRow({
    required Key key,
    required String dotsId,
    required double height,
    required int count,
    required int selected,
    required Widget Function(int index, double width) item,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (fit, tileWidth) = _fitIn(constraints.maxWidth);
        final visible = fit.clamp(1, count);
        final row = SizedBox(
          height: height,
          child: HomeRowWindow(
            key: key,
            count: count,
            visible: visible,
            selected: selected,
            builder: (start) => Row(
              children: [
                for (var i = start; i < start + visible; i++) ...[
                  if (i > start) const SizedBox(width: episodeGap),
                  item(i, tileWidth),
                ],
              ],
            ),
          ),
        );
        final pages = (count + fit - 1) ~/ fit;
        if (pages <= 1) return row;
        final scheme = Theme.of(context).colorScheme;
        final active = (selected ~/ fit).clamp(0, pages - 1);
        final shown = pages.clamp(1, _maxDots);
        final from = (active - shown ~/ 2).clamp(0, pages - shown);
        final to = from + shown;
        bool more(int page) =>
            (page == from && from > 0) || (page == to - 1 && to < pages);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            const SizedBox(height: _dotsGap),
            Row(
              key: ValueKey('${dotsId}_dots'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var page = from; page < to; page++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    // El de la página actual se estira: se lee de lejos.
                    width: page == active
                        ? _dotSize * 2.4
                        : more(page)
                        ? _dotSize * 0.6
                        : _dotSize,
                    height: more(page) ? _dotSize * 0.6 : _dotSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_dotSize),
                      color: page == active
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Las temporadas ("1", "2"…; el rótulo "Temporadas" ya dice qué son), de
  /// cristal como los capítulos: la que se
  /// ve, con el borde del foco si la fila lo tiene y sólida en el acento si
  /// no ([_SeasonPill]). ←/→ pasan de una a otra.
  Widget _seasonList() {
    final focused = _seasonsFocus.hasFocus;
    final current = _seasonIndex;
    return Focus(
      focusNode: _seasonsFocus,
      onKeyEvent: _onSeasonsKey,
      child: _edgeRow(
        key: const ValueKey('seasons'),
        dotsId: 'seasons',
        height: seasonHeight,
        count: _seasons.length,
        selected: current,
        item: (i, width) => _SeasonPill(
          key: ValueKey('season-${_seasons[i].number}'),
          width: width,
          label: '${_seasons[i].number}',
          current: i == current,
          focused: focused && i == current,
          onTap: () {
            _seasonsFocus.requestFocus();
            _selectSeason(i);
          },
        ),
      ),
    );
  }

  /// Los capítulos de la temporada en una fila ([_edgeRow]).
  Widget _episodeGrid(BuildContext context, ColorScheme scheme) {
    final Widget content;
    if (_loading.contains(_seasonId) ||
        (_detail == null && !_failed.contains(_seasonId))) {
      content = _loadingRow(scheme);
    } else if (_episodes.isEmpty) {
      content = SizedBox(
        height: episodeHeight,
        child: Center(
          child: Text(
            _failed.contains(_seasonId)
                ? LocaleKeys.series_episodes_error.tr()
                : LocaleKeys.series_episodes_empty.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      final episodes = _episodes;
      final focused = _episodesFocus.hasFocus;
      content = _edgeRow(
        // Otra temporada empieza desde su primer capítulo.
        key: ValueKey(_seasonId),
        dotsId: 'episodes',
        height: episodeHeight,
        count: episodes.length,
        selected: _episode,
        item: (i, width) => _EpisodeTile(
          key: ValueKey('episode-${episodes[i].number}'),
          width: width,
          number: episodes[i].number,
          selected: focused && i == _episode,
          current: i == _episode,
          onTap: () {
            _episodesFocus.requestFocus();
            _selectEpisode(i);
          },
        ),
      );
    }
    return Focus(
      focusNode: _episodesFocus,
      onKeyEvent: _onEpisodesKey,
      child: content,
    );
  }
}

/// Una temporada, del mismo cristal que los capítulos ([_EpisodeTile]): con
/// el foco en la fila, la que se ve lleva sólo el borde del foco; sin él,
/// queda sólida en el acento para que se sepa cuál es.
class _SeasonPill extends StatelessWidget {
  const _SeasonPill({
    super.key,
    required this.width,
    required this.label,
    required this.current,
    required this.focused,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool current;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final solid = current && !focused;
    final text = Text(
      label,
      maxLines: 1,
      style: MoaiText.display(
        context,
        fontSize: 15,
        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
        color: solid ? scheme.onPrimary : scheme.onSurface,
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: solid
          ? Container(
              width: width,
              height: SeriesDetailScreenState.seasonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: text,
            )
          : MoaiGlass(
              width: width,
              height: SeriesDetailScreenState.seasonHeight,
              borderRadius: 10,
              elevated: false,
              solid: true,
              focused: focused,
              alignment: Alignment.center,
              child: text,
            ),
    );
  }
}

/// Un capítulo: recuadro de cristal con su número; elegido, con el borde
/// del foco.
class _EpisodeTile extends StatelessWidget {
  const _EpisodeTile({
    super.key,
    required this.width,
    required this.number,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final double width;
  final int number;
  final bool selected;

  /// El elegido aunque el foco esté en otro lado: el número más marcado.
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: MoaiGlass(
        width: width,
        height: SeriesDetailScreenState.episodeHeight,
        borderRadius: 10,
        elevated: false,
        solid: true,
        focused: selected,
        alignment: Alignment.center,
        child: Text(
          '$number',
          style: MoaiText.display(
            context,
            fontSize: 17,
            fontWeight: current ? FontWeight.w800 : FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
