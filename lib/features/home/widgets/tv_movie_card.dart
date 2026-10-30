import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_filled_star.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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
  });

  @override
  State<TvMovieCard> createState() => _TvMovieCardState();
}

class _TvMovieCardState extends State<TvMovieCard> {
  bool _isFocused = false;

  /// El dorado del puntaje alto del detalle; en tema claro, más oscuro para
  /// que se lea.
  static Color _goldFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFBBF24)
      : const Color(0xFFB45309);

  IconData get _cardIcon {
    if (widget.movie.isTrailer) return MoaiIcons.vodTrailer;
    if (widget.movie.isSeries) return MoaiIcons.vodSeries;
    return MoaiIcons.vodMovie;
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
    // Sobre el fondo ambiente la tarjeta es de cristal; fuera, estilo opaco.
    final glass = MoaiGlassScope.enabledOf(context);
    final emptyColor = _emptyWellColor(scheme, glass: glass);

    final card = GestureDetector(
      onTap: () {
        widget.focusNode?.requestFocus();
        widget.onTap();
      },
      child: _movieCardChrome(
        glass: glass,
        isFocused: isFocused,
        scheme: scheme,
        child: _content(context, scheme, isFocused, emptyColor),
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
  Widget _content(
    BuildContext context,
    ColorScheme scheme,
    bool isFocused,
    Color emptyColor,
  ) {
    final glass = MoaiGlassScope.enabledOf(context);
    final poster = widget.movie.poster;
    final cardIcon = _cardIcon;
    return ClipRRect(
      borderRadius: BorderRadius.circular(glass ? 12 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (poster != null && poster.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    fadeInDuration: const Duration(milliseconds: 180),
                    fadeOutDuration: const Duration(milliseconds: 180),
                    placeholder: (context, url) => Container(
                      color: emptyColor,
                      child: Icon(
                        cardIcon,
                        size: MoaiIconSizes.xxl,
                        color: scheme.outline,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: emptyColor,
                      child: Icon(
                        cardIcon,
                        size: MoaiIconSizes.xxl,
                        color: scheme.outline,
                      ),
                    ),
                  )
                else
                  Container(
                    color: emptyColor,
                    child: Icon(
                      cardIcon,
                      size: MoaiIconSizes.xxl,
                      color: scheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.movie.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isFocused ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                // Las buenas (> 7) llevan una estrella en la barra del
                // título: el póster queda entero.
                if (widget.movie.isWellRated) ...[
                  const SizedBox(width: 4),
                  MoaiFilledStar(
                    key: const ValueKey('movie_card_well_rated'),
                    size: MoaiIconSizes.xs,
                    color: _goldFor(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco de la tarjeta: cristal (el borde del foco se pinta encima del
/// póster) o el estilo opaco de siempre.
Widget _movieCardChrome({
  required bool glass,
  required bool isFocused,
  required ColorScheme scheme,
  required Widget child,
}) {
  if (glass) {
    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
      focused: isFocused,
      child: child,
    );
  }
  return AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isFocused
            ? scheme.primary
            : scheme.outlineVariant.withValues(alpha: 0.48),
        width: isFocused ? 2.5 : 1.0,
      ),
    ),
    child: child,
  );
}

/// Fondo del lugar del póster cuando no hay imagen: en cristal un "pozo"
/// tenue en vez de un bloque opaco.
Color _emptyWellColor(ColorScheme scheme, {required bool glass}) => glass
    ? (scheme.brightness == Brightness.dark ? Colors.white : scheme.onSurface)
          .withValues(alpha: 0.04)
    : scheme.surfaceContainerLowest;

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
    final glass = MoaiGlassScope.enabledOf(context);
    final accent = isSelected ? scheme.primary : scheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: _movieCardChrome(
        glass: glass,
        isFocused: isSelected,
        scheme: scheme,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(glass ? 12 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: _emptyWellColor(scheme, glass: glass),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        MoaiIcons.moviesShowAll,
                        size: MoaiIconSizes.xxl,
                        color: isSelected ? scheme.primary : scheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        LocaleKeys.movies_show_all.tr(),
                        style: MoaiText.display(
                          context,
                          fontSize: 16,
                          color: accent,
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
