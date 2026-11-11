import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_image_cache.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/image_decode.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';

/// Piezas de la ficha que comparten el detalle de películas y el de series.

/// Tamaño de la foto difuminada de arriba a la derecha ([MovieDetailAmbient]).
const double movieDetailAmbientWidth = 525;
const double movieDetailAmbientHeight = 285;

/// Foto difuminada arriba a la derecha. Va en su propia capa: la Hero de al
/// lado cambia de foto cada 4 s y, sin esto, las máscaras se repintaban en
/// cada cuadro del fundido.
class MovieDetailAmbient extends StatelessWidget {
  const MovieDetailAmbient({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) {
          // Desvanecimiento suave en X: el borde izquierdo se vuelve 100% transparente
          return const LinearGradient(
            colors: [Colors.transparent, Colors.white],
            stops: [0.0, 0.40],
          ).createShader(bounds);
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            // Desvanecimiento suave en Y: el borde inferior se vuelve 100% transparente
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.transparent],
              stops: [0.45, 1.0],
            ).createShader(bounds);
          },
          // La transparencia va en la imagen misma (sin una capa más de
          // Opacity).
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            cacheManager: MovieImageCache.photos,
            fit: BoxFit.cover,
            color: Colors.white.withValues(alpha: 0.70),
            colorBlendMode: BlendMode.modulate,
            // Al tamaño del recuadro, no al de la foto (hasta 4096 px).
            memCacheWidth: coverDecodeWidth(
              width: movieDetailAmbientWidth,
              height: movieDetailAmbientHeight,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            ),
            alignment: Alignment.centerRight,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// El título de la ficha; en cristal, con el degradado de dos colores de los
/// títulos de los paneles y diálogos ([HomeClock.timeShader]). El Align
/// ajusta el degradado al ancho del texto.
class MovieDetailTitle extends StatelessWidget {
  const MovieDetailTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = MoaiGlassScope.enabledOf(context);
    final title = Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: MoaiText.display(
        context,
        color: glass ? Colors.white : scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
    );
    if (!glass) return title;
    return Align(
      alignment: Alignment.centerLeft,
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: HomeClock.timeShader,
        child: title,
      ),
    );
  }
}

/// El título original (alias) debajo del título.
class MovieDetailAlias extends StatelessWidget {
  const MovieDetailAlias(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MoaiText.body(
        context,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// La nota, con el color según cuánto es; `null` si no tiene.
TvMetaPill? movieScorePill(BuildContext context, MovieItem movie) {
  final scoreText = movie.formattedScore;
  if (scoreText == null || scoreText.isEmpty) return null;

  final scheme = Theme.of(context).colorScheme;
  final val = double.tryParse(movie.score ?? '');
  // En tema claro, el mismo tono más oscuro para que se lea sobre el fondo.
  final dark = Theme.of(context).brightness == Brightness.dark;

  final Color bg;
  final Color fg;

  if (val != null) {
    if (val > 7.0) {
      // > 7.0: Amarillo / Dorado
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.22);
      fg = dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
    } else if (val >= 5.0) {
      // 5.0 a 7.0: Plata / Gris
      bg = const Color(0xFF94A3B8).withValues(alpha: 0.24);
      fg = dark ? const Color(0xFFE2E8F0) : const Color(0xFF475569);
    } else {
      // < 5.0: Rojo
      bg = const Color(0xFFEF4444).withValues(alpha: 0.24);
      fg = dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    }
  } else {
    bg = scheme.tertiaryContainer;
    fg = scheme.onTertiaryContainer;
  }

  // En cristal, la etiqueta es como las de al lado (año, duración) y el
  // color de la nota va en la estrella y el número, en el tono que se lee
  // sobre el blanco (en el oscuro, sobre el ahumado: el claro de arriba).
  final Color? onGlass = val == null
      ? null
      : val > 7.0
      ? (dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
      : val >= 5.0
      ? (dark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B))
      : (dark ? const Color(0xFFF87171) : const Color(0xFFDC2626));

  return TvMetaPill(
    dense: true,
    color: bg,
    foreground: fg,
    glassForeground: onGlass,
    icon: MoaiIcons.vodRatingFilled,
    label: scoreText,
  );
}

/// El gris de los rótulos de la ficha ("Director:", "Temporadas"…).
TextStyle movieDetailLabelStyle(BuildContext context) => MoaiText.body(
  context,
  fontSize: 12.5,
  fontWeight: FontWeight.w700,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

/// "Director: …" o "Elenco: …".
class MovieCreditRow extends StatelessWidget {
  const MovieCreditRow({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: movieDetailLabelStyle(context)),
        Expanded(
          child: Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Sinopsis" y el texto, en todo el alto que le den (va en un Expanded):
/// sin foco ni scroll, la letra se achica para que entre.
class MovieSynopsisBlock extends StatelessWidget {
  const MovieSynopsisBlock({super.key, required this.description});

  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = description?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.movies_synopsis.tr(),
          style: MoaiText.body(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: _SynopsisText(
            text: text.isNotEmpty
                ? text
                : LocaleKeys.movies_synopsis_empty.tr(),
            color: scheme.onSurface.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}

/// La sinopsis sin scroll ni foco: con la letra más grande (de [maxSize] a
/// [minSize]) con la que entra entera en el alto que queda. Si ni con la más
/// chica entra, se corta con "…".
class _SynopsisText extends StatelessWidget {
  const _SynopsisText({required this.text, required this.color});

  final String text;
  final Color color;

  static const double maxSize = 12;
  static const double minSize = 10;
  static const double _step = 0.5;
  static const double _lineHeight = 1.35;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        TextStyle style(double size) => MoaiText.body(
          context,
          fontSize: size,
          height: _lineHeight,
          color: color,
        );

        var size = maxSize;
        while (size > minSize) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style(size)),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          final fits = painter.height <= constraints.maxHeight;
          painter.dispose();
          if (fits) break;
          size -= _step;
        }
        final lines =
            constraints.maxHeight / (scaler.scale(size) * _lineHeight);
        return Text(
          text,
          style: style(size),
          maxLines: lines.floor().clamp(1, 1000),
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
