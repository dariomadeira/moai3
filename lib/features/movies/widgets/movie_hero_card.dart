import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/image_decode.dart';
import 'package:moai3/utils/image_tint.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Botones de [MovieHeroCard], en el orden de ←/→.
enum MovieHeroAction { play, interesting, more, previous, next }

/// Tarjeta destacada de una película (REDISEÑO, referencia estilo visionOS):
/// la imagen horizontal de fondo, los géneros, el
/// título, la sinopsis y los botones Reproducir / Interesante / más; con
/// varias películas, flechas para pasar de una a otra (no cambia sola).
///
/// No sabe de dónde salen las películas ni qué pantalla la muestra: recibe la
/// lista y qué hacer en cada botón, así se puede usar en cualquier lado.
///
/// Como la grilla de Películas, tiene un único [focusNode]: el botón elegido
/// es un índice y los botones ([MoaiPillButton]) sólo lo dibujan. ←/→
/// recorren los botones; ← desde el primero llama a [onExitLeft]; OK hace
/// la acción. Las flechas cambian de película y el foco se queda en ellas.
class MovieHeroCard extends StatefulWidget {
  const MovieHeroCard({
    super.key,
    required this.movies,
    required this.focusNode,
    this.onPlay,
    required this.onOpen,
    this.onToggleInteresting,
    this.isInteresting,
    this.onExitLeft,
    this.onExitRight,
    this.onExitUp,
    this.onExitDown,
    this.wideImage = false,
    this.tintFromImage = false,
    this.elevated = true,
    this.initialIndex = 0,
    this.onMovieChanged,
    this.playLabel,
    this.showMore = true,
    this.showActions = true,
    this.glassFrame = false,
    this.autoAdvance,
    this.crossFade = false,
  });

  /// Al pasar de película, la foto y los textos nuevos aparecen de a poco
  /// sobre los anteriores (medio segundo con dos fotos a la vez); sin esto
  /// cambian de golpe. Pensado para la tarjeta sin botones ([showActions]).
  final bool crossFade;

  /// Con botones (Reproducir, Marcar, más y las flechas). Sin ellos la
  /// tarjeta entera es un solo destino: OK o un toque abren el detalle
  /// ([onOpen]) y ←/→ salen ([onExitLeft], [onExitRight]).
  final bool showActions;

  /// Con el marco de cristal de las tarjetas de película ([TvMovieCard]), que
  /// con foco se pinta del acento, y la foto adentro con su margen; sin él,
  /// el bloque del color de la foto hasta el borde.
  final bool glassFrame;

  /// Cada cuánto pasa sola a la película siguiente (con más de una); `null`,
  /// no pasa sola. No corre con otra pantalla encima ni con la app en
  /// segundo plano.
  final Duration? autoAdvance;

  /// El botón principal; por defecto "Reproducir". Las series dicen "Ver
  /// serie" (abre el detalle: desde acá no se sabe qué capítulo).
  final String? playLabel;

  /// El botón "…" (abre el detalle). Las series no lo llevan: el principal
  /// ya abre el detalle.
  final bool showMore;

  /// Película con que empieza (el Inicio la va rotando entre arranques).
  final int initialIndex;

  /// Se pasó a otra película con las flechas.
  final ValueChanged<MovieItem>? onMovieChanged;

  /// Con la sombra de los paneles. Adentro de una lista va sin: la lista la
  /// corta derecho en su borde.
  final bool elevated;

  /// El fondo (y aquello en lo que se funde la foto) es el color
  /// predominante de la foto, oscurecido ([imageTint]), en vez de negro.
  final bool tintFromImage;

  /// Para una tarjeta más ancha que 16:9 (el banner de Películas): la foto
  /// entera a 16:9 contra la derecha, en vez de cubrir todo y recortarse.
  final bool wideImage;

  final List<MovieItem> movies;
  final FocusNode focusNode;

  final ValueChanged<MovieItem>? onPlay;

  /// "Más": el detalle de la película.
  final ValueChanged<MovieItem> onOpen;
  final ValueChanged<MovieItem>? onToggleInteresting;
  final bool Function(MovieItem movie)? isInteresting;

  final VoidCallback? onExitLeft;

  /// → desde el último botón.
  final VoidCallback? onExitRight;
  final VoidCallback? onExitUp;
  final VoidCallback? onExitDown;

  /// Proporción de la tarjeta (ancho / alto): 16:9, la de las imágenes
  /// horizontales del catálogo, así se ven enteras (con 2,2 se cortaban
  /// arriba y abajo y la tarjeta quedaba baja).
  static const double aspectRatio = 16 / 9;

  /// Mismas esquinas que el panel.
  static const double radius = MoaiGlass.panelRadius;

  @override
  State<MovieHeroCard> createState() => MovieHeroCardState();
}

class MovieHeroCardState extends State<MovieHeroCard> {
  late int _movie =
      widget.initialIndex >= 0 && widget.initialIndex < widget.movies.length
      ? widget.initialIndex
      : 0;
  int _action = 0;

  /// Alto de todos los botones (acciones y flechas ‹ ›): iguales.
  static const double _buttonSize = 29;

  /// Separación entre géneros, entre botones y entre las flechas: una sola.
  static const double _gap = 10;

  /// Ancho de decodificación de la última pasada (para precargar al mismo).
  int _decodeWidth = 0;

  /// Película, ancho y lista de la última precarga: no se repite en cada
  /// pasada.
  (int, int, List<MovieItem>)? _precachedFor;

  /// Color de fondo de cada foto (por url), con [MovieHeroCard.tintFromImage].
  final Map<String, Color> _tints = {};
  final Set<String> _tintRequested = {};

  @visibleForTesting
  int get debugMovieIndex => _movie;

  @visibleForTesting
  MovieHeroAction get debugAction => _actions[_action];

  /// Lo que tarda en pasar de una película a otra: el color de fondo y, con
  /// [MovieHeroCard.crossFade], la foto y los textos.
  static const Duration _fadeDuration = Duration(milliseconds: 500);

  /// El paso automático ([MovieHeroCard.autoAdvance]).
  Timer? _autoTimer;

  /// Apagado con otra pantalla encima: ahí no se pasa de película.
  ValueListenable<TickerModeData>? _tickerMode;

  /// Las flechas sólo con más de una película.
  List<MovieHeroAction> get _actions => [
    if (widget.showActions) ...[
      MovieHeroAction.play,
      MovieHeroAction.interesting,
      if (widget.showMore) MovieHeroAction.more,
      if (widget.movies.length > 1) ...[
        MovieHeroAction.previous,
        MovieHeroAction.next,
      ],
    ],
  ];

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
    _restartAuto();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.getValuesNotifier(context);
  }

  void _restartAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    final every = widget.autoAdvance;
    if (every == null || widget.movies.length < 2) return;
    _autoTimer = Timer.periodic(every, (_) => _autoNext());
  }

  void _autoNext() {
    if (!mounted || widget.movies.length < 2) return;
    if (!(_tickerMode?.value.enabled ?? true)) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    _run(MovieHeroAction.next);
  }

  @override
  void didUpdateWidget(covariant MovieHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
    if (_movie >= widget.movies.length) _movie = 0;
    if (_action >= _actions.length) _action = 0;
    if (oldWidget.autoAdvance != widget.autoAdvance ||
        (oldWidget.movies.length > 1) != (widget.movies.length > 1)) {
      _restartAuto();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  MovieItem get _current => widget.movies[_movie];

  void _run(MovieHeroAction action) {
    final count = widget.movies.length;
    switch (action) {
      case MovieHeroAction.play:
        widget.onPlay?.call(_current);
      case MovieHeroAction.interesting:
        widget.onToggleInteresting?.call(_current);
      case MovieHeroAction.more:
        widget.onOpen(_current);
      case MovieHeroAction.previous:
        setState(() => _movie = (_movie - 1 + count) % count);
        widget.onMovieChanged?.call(_current);
      case MovieHeroAction.next:
        setState(() => _movie = (_movie + 1) % count);
        widget.onMovieChanged?.call(_current);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.movies.isEmpty) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_action > 0) {
        setState(() => _action--);
      } else {
        widget.onExitLeft?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (repeat) return KeyEventResult.handled;
      if (_action < _actions.length - 1) {
        setState(() => _action++);
      } else {
        widget.onExitRight?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.onExitUp == null) return KeyEventResult.ignored;
      widget.onExitUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.onExitDown == null) return KeyEventResult.ignored;
      widget.onExitDown!();
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      if (_actions.isEmpty) {
        widget.onOpen(_current);
      } else {
        _run(_actions[_action]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.movies.isEmpty) return const SizedBox.shrink();
    final movie = _current;
    final focused = widget.focusNode.hasFocus;
    final selected = focused && _actions.isNotEmpty ? _actions[_action] : null;
    final borderRadius = BorderRadius.circular(MovieHeroCard.radius);

    // Como el detalle de la película: tarjeta negra, sin filo de luz, y la
    // foto que se funde en el negro hacia la izquierda y hacia abajo. UN solo
    // recorte redondeado para todo (si cada capa se redondea por su cuenta,
    // sus bordes suavizados se suman y queda una línea en la esquina).
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Con [MovieHeroCard.wideImage] la foto no ocupa todo el ancho: es
          // el recuadro 16:9 de [_fadedImage].
          _decodeWidth = coverDecodeWidth(
            width: widget.wideImage
                ? math.min(
                    constraints.maxWidth,
                    constraints.maxHeight * MovieHeroCard.aspectRatio,
                  )
                : constraints.maxWidth,
            height: constraints.maxHeight,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          );
          _precacheAround();
          final image = _provider(movie);
          final content = Stack(
            fit: StackFit.expand,
            children: [
              // En su propia capa: las máscaras no se repintan
              // cuando animan los botones.
              _switching(
                movie,
                image == null
                    ? const SizedBox.expand()
                    : RepaintBoundary(child: _fadedImage(image)),
              ),
              // Los botones animan al elegirse: en su propia capa, así
              // no se vuelve a pintar la foto.
              _switching(
                movie,
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _content(
                      context,
                      movie,
                      selected,
                      constraints.maxWidth,
                    ),
                  ),
                ),
              ),
            ],
          );
          // Al pasar de película el color (fondo y filo) cambia de a poco;
          // la foto y los botones están en sus capas y no se repintan.
          return TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: _tintOf(movie)),
            duration: widget.crossFade
                ? _fadeDuration
                : const Duration(milliseconds: 400),
            child: content,
            builder: (context, color, child) {
              final background = color ?? Colors.black;
              if (widget.glassFrame) {
                // Como [TvMovieCard]: el marco de cristal (del acento con
                // foco) y adentro, con su margen, la foto redondeada.
                return GestureDetector(
                  onTap: widget.showActions
                      ? null
                      : () {
                          widget.focusNode.requestFocus();
                          widget.onOpen(_current);
                        },
                  child: MoaiGlass(
                    borderRadius: TvMovieCard.radius,
                    elevated: false,
                    solid: true,
                    focused: focused,
                    padding: const EdgeInsets.all(TvMovieCard.posterInset),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        TvMovieCard.posterRadius,
                      ),
                      child: ColoredBox(color: background, child: child),
                    ),
                  ),
                );
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: widget.elevated
                      ? MoaiGlass.panelShadowOf(context)
                      : null,
                ),
                // Filo fino encima del recorte: separa la foto del fondo
                // ambiente y tapa el suavizado de las esquinas. Gris oscuro
                // (2026-11-04; antes negro, que se veía duro); con color de
                // fondo, ese mismo color (2026-11-11: el más claro se veía
                // como un marco).
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: widget.tintFromImage
                          ? background
                          : const Color(0xFF4B5563),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: borderRadius,
                    child: ColoredBox(color: background, child: child),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Con [MovieHeroCard.crossFade], [child] (la foto o los textos de
  /// [movie]) aparece de a poco sobre el de la película anterior; sin él,
  /// cambia de golpe.
  Widget _switching(MovieItem movie, Widget child) {
    if (!widget.crossFade) return child;
    return AnimatedSwitcher(
      duration: _fadeDuration,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: KeyedSubtree(
        key: ValueKey(
          movie.contentId.isNotEmpty ? movie.contentId : movie.name,
        ),
        child: child,
      ),
    );
  }

  /// La foto con la transparencia del detalle: entera a la derecha y arriba,
  /// 100% transparente en el borde izquierdo y en el de abajo, donde van el
  /// texto y los botones sobre el negro.
  Widget _fadedImage(ImageProvider image) {
    final faded = ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.transparent, Colors.white],
        stops: [0.1, 0.6],
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.transparent],
          stops: [0.45, 1],
        ).createShader(bounds),
        child: Image(
          image: image,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    if (!widget.wideImage) return faded;
    // Las máscaras van sobre la foto: se funde en su propio borde izquierdo.
    return Align(
      alignment: Alignment.centerRight,
      child: AspectRatio(aspectRatio: MovieHeroCard.aspectRatio, child: faded),
    );
  }

  /// La foto de [movie] decodificada al tamaño de la tarjeta (las del
  /// catálogo llegan a 4096 px).
  ImageProvider? _provider(MovieItem movie) {
    final url = _imageOf(movie);
    if (url == null) return null;
    return ResizeImage(
      _photo(url),
      width: _decodeWidth,
      policy: ResizeImagePolicy.fit,
    );
  }

  Color _tintOf(MovieItem movie) {
    if (!widget.tintFromImage) return Colors.black;
    return _tints[_imageOf(movie)] ?? Colors.black;
  }

  static ImageProvider _photo(String url) =>
      CachedNetworkImageProvider(url, cacheManager: MovieImageCache.photos);

  /// Precarga las fotos de la película anterior y la siguiente: ‹ › las
  /// muestran sin espera (todas juntas llenaban la memoria de imágenes y se
  /// descartaban). Con [MovieHeroCard.tintFromImage], el color de fondo de
  /// todas, que es una decodificación chiquita.
  void _precacheAround() {
    if (widget.tintFromImage) {
      for (final movie in widget.movies) {
        final url = _imageOf(movie);
        if (url == null || !_tintRequested.add(url)) continue;
        imageTint(_photo(url)).then((color) {
          if (color != null && mounted) setState(() => _tints[url] = color);
        });
      }
    }
    final count = widget.movies.length;
    final target = (_movie, _decodeWidth, widget.movies);
    if (count < 2 || target == _precachedFor) return;
    _precachedFor = target;
    final neighbors = {(_movie - 1 + count) % count, (_movie + 1) % count};
    final providers = [
      for (final index in neighbors) ?_provider(widget.movies[index]),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final provider in providers) {
        precacheImage(provider, context, onError: (_, _) {});
      }
    });
  }

  /// La imagen horizontal; si no hay, el póster.
  static String? _imageOf(MovieItem movie) {
    for (final url in [movie.backdrop, ...movie.backdrops, movie.poster]) {
      if (url != null && url.trim().isNotEmpty) return url;
    }
    return null;
  }

  Widget _content(
    BuildContext context,
    MovieItem movie,
    MovieHeroAction? selected,
    double cardWidth,
  ) {
    final interesting = widget.isInteresting?.call(movie) ?? false;
    final description = (movie.description ?? '').trim();
    // El título crece con la tarjeta (en el Chromecast ronda los 23).
    final titleSize = (cardWidth * 0.043).clamp(18.0, 31.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FractionallySizedBox(
            widthFactor: 0.62,
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movie.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    fontSize: titleSize,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
                if (description.isNotEmpty)
                  Flexible(child: _description(context, description)),
              ],
            ),
          ),
        ),
        if (widget.showActions) const SizedBox(height: 14),
        if (widget.showActions)
          Row(
            // Las acciones usan todo el ancho que dejan las flechas (con un
            // Spacer se repartían mitad y mitad y los botones se encogían).
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sólo en una tarjeta muy angosta se achican, no desbordan.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _button(
                        MovieHeroAction.play,
                        selected,
                        kind: MoaiPillButtonKind.glass,
                        icon: MoaiIcons.vodPlay,
                        label: widget.playLabel ?? LocaleKeys.movies_play.tr(),
                      ),
                      const SizedBox(width: _gap),
                      _button(
                        MovieHeroAction.interesting,
                        selected,
                        kind: MoaiPillButtonKind.glass,
                        icon: interesting
                            ? MoaiIcons.vodWatchlistRemove
                            : MoaiIcons.vodWatchlist,
                        label: interesting
                            ? LocaleKeys.movies_hero_watchlist_added.tr()
                            : LocaleKeys.movies_hero_watchlist_add.tr(),
                      ),
                      if (widget.showMore) ...[
                        const SizedBox(width: _gap),
                        _button(
                          MovieHeroAction.more,
                          selected,
                          kind: MoaiPillButtonKind.round,
                          icon: MoaiIcons.moviesMore,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.movies.length > 1)
                Padding(
                  padding: const EdgeInsets.only(left: _gap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _button(
                        MovieHeroAction.previous,
                        selected,
                        kind: MoaiPillButtonKind.round,
                        icon: MoaiIcons.chevronLeft,
                      ),
                      const SizedBox(width: _gap),
                      _button(
                        MovieHeroAction.next,
                        selected,
                        kind: MoaiPillButtonKind.round,
                        icon: MoaiIcons.chevronRight,
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// La sinopsis con las líneas que entran (hasta 2): en una tarjeta baja
  /// se acorta o desaparece en vez de desbordar.
  Widget _description(BuildContext context, String text) {
    const fontSize = 12.0;
    const lineHeight = 1.35;
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final lines = ((constraints.maxHeight - gap) / (fontSize * lineHeight))
            .floor()
            .clamp(0, 2);
        if (lines == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: gap),
          child: Text(
            text,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              height: lineHeight,
              color: const Color(0xC7FFFFFF),
            ),
          ),
        );
      },
    );
  }

  Widget _button(
    MovieHeroAction action,
    MovieHeroAction? selected, {
    required MoaiPillButtonKind kind,
    required IconData icon,
    String? label,
    double size = _buttonSize,
  }) {
    return MoaiPillButton(
      key: ValueKey('movie_hero_${action.name}'),
      kind: kind,
      size: size,
      icon: icon,
      label: label,
      selected: selected == action,
      onTap: () {
        widget.focusNode.requestFocus();
        setState(() => _action = _actions.indexOf(action));
        _run(action);
      },
    );
  }
}
