import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';

/// Tarjeta de película Moiamov para Smart TV con soporte D-Pad.
class TvMovieCard extends StatefulWidget {
  final MovieItem movie;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final bool Function()? onKeyLeft;
  final bool Function()? onKeyRight;

  /// Lo elige quien la contiene (p. ej. la grilla, con un solo foco): la
  /// tarjeta no toma foco ni maneja teclas, sólo se dibuja elegida.
  final bool? isSelected;

  /// REDISEÑO: con una imagen horizontal (16:9) de la película en vez del
  /// póster (Interesantes del Inicio). Sin ninguna, el póster recortado.
  final bool wide;

  /// Cuánto se vio (0–1, Seguir viendo): una barra abajo de la imagen. Sin
  /// dato o en 0, sin barra.
  final double? progress;

  /// Se está abriendo (Seguir viendo pide el video): muestra que carga.
  final bool isLoading;

  const TvMovieCard({
    super.key,
    required this.movie,
    this.focusNode,
    required this.onTap,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyLeft,
    this.onKeyRight,
    this.isSelected,
    this.wide = false,
    this.progress,
    this.isLoading = false,
  });

  /// REDISEÑO (cristal): como los días de Descuentos, una tarjeta de
  /// cristal que se enfoca con el borde del acento; adentro el póster, un
  /// poco más chico (con [posterInset] de margen) y redondeado, y abajo el
  /// nombre.
  static const double radius = 10;
  static const double posterRadius = 6;
  static const double posterInset = 5;

  /// Alto de la barra del nombre, debajo del póster.
  static const double titleBarHeight = 24;

  /// Proporción del afiche (262:370) y de la imagen horizontal ([wide]).
  static const double posterAspect = 262 / 370;
  static const double wideAspect = 16 / 9;

  /// Ancho en píxeles al que se decodifica un póster: en el TV se dibuja a
  /// unos 250.
  static const int posterDecodeWidth = 280;

  /// El póster de [url] tal como lo pide la tarjeta, para precargarlo (si
  /// no coincide, la precarga no le sirve).
  static ImageProvider posterImage(String url) => ResizeImage.resizeIfNeeded(
    posterDecodeWidth,
    null,
    CachedNetworkImageProvider(url, cacheManager: MovieImageCache.posters),
  );

  /// Alto de la tarjeta para un ancho dado: la imagen entera, sin
  /// deformarse, con su margen, más la barra del nombre.
  static double heightForWidth(double width, {bool wide = false}) =>
      posterInset +
      (width - 2 * posterInset) / (wide ? wideAspect : posterAspect) +
      titleBarHeight;

  /// Ancho de la tarjeta para un alto dado (la inversa de [heightForWidth]).
  static double widthForHeight(double height, {bool wide = false}) =>
      (height - posterInset - titleBarHeight) *
          (wide ? wideAspect : posterAspect) +
      2 * posterInset;

  @override
  State<TvMovieCard> createState() => _TvMovieCardState();
}

class _TvMovieCardState extends State<TvMovieCard> {
  bool _isFocused = false;

  /// Lo que se ve en el lugar del póster mientras carga o si no hay: el
  /// ícono del tipo (las series, el SVG del rail).
  Widget _placeholder(ColorScheme scheme, Color emptyColor) {
    final movie = widget.movie;
    final color = scheme.outline;
    return Container(
      color: emptyColor,
      alignment: Alignment.center,
      child: movie.isTrailer
          ? Icon(MoaiIcons.vodTrailer, size: MoaiIconSizes.xxl, color: color)
          : movie.isSeries
          ? MoaiSvgIcon(
              MoaiIcons.seriesSvg,
              size: MoaiIconSizes.xxl,
              color: color,
            )
          : Icon(MoaiIcons.vodMovie, size: MoaiIconSizes.xxl, color: color),
    );
  }

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode?.hasFocus ?? false;
  }

  @override
  void didUpdateWidget(covariant TvMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode?.hasFocus ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFocused =
        widget.isSelected ??
        (_isFocused || (widget.focusNode?.hasFocus ?? false));
    final emptyColor = _emptyWellColor(scheme);

    final card = GestureDetector(
      onTap: () {
        widget.focusNode?.requestFocus();
        widget.onTap();
      },
      child: _movieCardChrome(
        isFocused: isFocused,
        child: _content(context, scheme, emptyColor),
      ),
    );
    if (widget.isSelected != null) return card;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (key == LogicalKeyboardKey.arrowRight) {
            if (event is KeyRepeatEvent) return KeyEventResult.handled;
            if (widget.onKeyRight != null && widget.onKeyRight!()) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (event is KeyRepeatEvent) return KeyEventResult.handled;
            if (widget.onKeyLeft != null && widget.onKeyLeft!()) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            if (widget.onKeyUp != null) {
              widget.onKeyUp!();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (widget.onKeyDown != null) {
              widget.onKeyDown!();
              return KeyEventResult.handled;
            }
          } else if (TvKeyHandler.isActionKey(key)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: card,
    );
  }

  /// Póster y título.
  Widget _content(BuildContext context, ColorScheme scheme, Color emptyColor) {
    final movie = widget.movie;
    final name = movie.name;
    // Las horizontales vienen de hasta 4096 px: se decodifican chicas.
    final poster = widget.wide && movie.stageImages.isNotEmpty
        ? movie.stageImages.first
        : movie.poster;
    final placeholder = _placeholder(scheme, emptyColor);
    final posterStack = Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null && poster.isNotEmpty)
          CachedNetworkImage(
            imageUrl: poster,
            fit: BoxFit.cover,
            cacheManager: widget.wide
                ? MovieImageCache.photos
                : MovieImageCache.posters,
            memCacheWidth: widget.wide ? 640 : TvMovieCard.posterDecodeWidth,
            fadeInDuration: const Duration(milliseconds: 180),
            fadeOutDuration: const Duration(milliseconds: 180),
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => placeholder,
          )
        else
          placeholder,
        if ((widget.progress ?? 0) > 0)
          Positioned(
            left: 8,
            right: 8,
            bottom: 7,
            child: _ProgressBar(value: widget.progress!.clamp(0.0, 1.0)),
          ),
        if (widget.isLoading)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(
              child: SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
    // El póster redondeado de los cuatro lados y abajo el nombre centrado
    // (el margen lo pone el marco).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(TvMovieCard.posterRadius),
            child: posterStack,
          ),
        ),
        SizedBox(
          height: TvMovieCard.titleBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de lo visto, sobre la imagen: pista blanca translúcida y lo visto
/// en el acento.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0x80FFFFFF)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: ColoredBox(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marco de la tarjeta: cristal como los días de Descuentos (borde del
/// acento con foco), con el contenido a [TvMovieCard.posterInset] del borde,
/// salvo abajo, donde ya deja aire la barra del nombre.
Widget _movieCardChrome({required bool isFocused, required Widget child}) {
  const inset = TvMovieCard.posterInset;
  return MoaiGlass(
    borderRadius: TvMovieCard.radius,
    elevated: false,
    solid: true,
    focused: isFocused,
    padding: const EdgeInsets.fromLTRB(inset, inset, inset, 0),
    child: child,
  );
}

/// Fondo del lugar del póster cuando no hay imagen: un "pozo" tenue en vez
/// de un bloque opaco.
Color _emptyWellColor(ColorScheme scheme) =>
    (scheme.brightness == Brightness.dark ? Colors.white : scheme.onSurface)
        .withValues(alpha: 0.04);

/// Último casillero de una categoría de la grilla: abre la categoría
/// completa (SPEC-44 §3.3). Mismo tamaño y marco que [TvMovieCard]; como
/// ella con `isSelected`, no toma foco: la elige la grilla.
class TvShowAllCard extends StatelessWidget {
  const TvShowAllCard({
    super.key,
    required this.categoryName,
    required this.isSelected,
    required this.onTap,
  });

  final String categoryName;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: _movieCardChrome(
        isFocused: isSelected,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvMovieCard.posterRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: _emptyWellColor(scheme),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // En gris aunque esté elegida: el marco ya lo marca.
                      Icon(
                        MoaiIcons.moviesShowAll,
                        size: MoaiIconSizes.lg,
                        color: scheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        LocaleKeys.movies_show_all.tr(),
                        style: MoaiText.display(
                          context,
                          fontSize: 13,
                          color: scheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
