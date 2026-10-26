import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Piezas de cristal del reproductor de películas. Van sobre el video, así
/// que siempre se pintan con el tema oscuro ([MoviePlayerDarkTheme]).

/// Fuerza el tema oscuro (mismo acento) para que el cristal se lea sobre el
/// video aunque la app esté en tema claro.
class MoviePlayerDarkTheme extends StatelessWidget {
  const MoviePlayerDarkTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) return child;
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.colorScheme.primary,
          brightness: Brightness.dark,
        ),
      ),
      child: child,
    );
  }
}

/// Franja superior: atrás, título y chips de calidad y audio.
class MoviePlayerTopBar extends StatelessWidget {
  const MoviePlayerTopBar({
    super.key,
    required this.title,
    required this.quality,
    required this.audio,
  });

  final String title;
  final String quality;
  final String audio;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return MoaiGlass(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: [
          // Atrás lo maneja el reproductor; acá es la guía visual.
          Container(
            width: 36,
            height: 36,
            decoration: moaiGlassChipDecoration(scheme),
            child: Icon(
              MoaiIcons.arrowBack,
              size: MoaiIconSizes.md,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.display(
                context,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (quality.isNotEmpty) ...[
            _Chip(icon: MoaiIcons.vodQuality, label: quality),
            const SizedBox(width: 8),
          ],
          _Chip(icon: MoaiIcons.vodAudio, label: audio),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: moaiGlassChipDecoration(scheme),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoaiIconSizes.sm, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel inferior: tiempo actual, barra (con el destino de la búsqueda si se
/// está buscando), tiempo restante y la ayuda de teclas.
class MoviePlayerBottomBar extends StatelessWidget {
  const MoviePlayerBottomBar({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    this.scrubTarget,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;

  /// Destino de la búsqueda en curso (todavía sin saltar).
  final Duration? scrubTarget;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final shown = scrubTarget ?? position;
    final remaining = duration > shown ? duration - shown : Duration.zero;
    final timeStyle = MoaiText.body(
      context,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
    );

    return MoaiGlass(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isPlaying ? MoaiIcons.vodPlay : MoaiIcons.vodPause,
                size: MoaiIconSizes.md,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 64,
                child: Text(formatPlayerTime(shown), style: timeStyle),
              ),
              Expanded(
                child: MoviePlayerProgressBar(
                  position: position,
                  duration: duration,
                  scrubTarget: scrubTarget,
                ),
              ),
              SizedBox(
                width: 72,
                child: Text(
                  duration > Duration.zero
                      ? '−${formatPlayerTime(remaining)}'
                      : '',
                  textAlign: TextAlign.right,
                  style: timeStyle.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KeyHints(isPlaying: isPlaying),
        ],
      ),
    );
  }
}

/// "◀ ▶ Buscar · OK Pausar".
class _KeyHints extends StatelessWidget {
  const _KeyHints({required this.isPlaying});

  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final style = MoaiText.body(
      context,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    );
    Widget key(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: moaiGlassChipDecoration(scheme, radius: 6),
      child: child,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        key(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                MoaiIcons.dpadLeft,
                size: MoaiIconSizes.xs,
                color: scheme.onSurface,
              ),
              Icon(
                MoaiIcons.dpadRight,
                size: MoaiIconSizes.xs,
                color: scheme.onSurface,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(LocaleKeys.movies_player_hint_seek.tr(), style: style),
        const SizedBox(width: 18),
        key(
          Text(
            'OK',
            style: style.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isPlaying
              ? LocaleKeys.movies_player_hint_pause.tr()
              : LocaleKeys.movies_player_hint_play.tr(),
          style: style,
        ),
      ],
    );
  }
}

/// Barra de progreso de cristal: lo visto con el acento y un punto; si se
/// está buscando, el punto va al destino y una marca tenue queda donde
/// estaba.
class MoviePlayerProgressBar extends StatelessWidget {
  const MoviePlayerProgressBar({
    super.key,
    required this.position,
    required this.duration,
    this.scrubTarget,
  });

  final Duration position;
  final Duration duration;
  final Duration? scrubTarget;

  static const double _track = 6;
  static const double _dot = 16;

  double _fraction(Duration d) => duration.inMilliseconds <= 0
      ? 0
      : (d.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final target = scrubTarget;
    final dotAt = _fraction(target ?? position);

    return SizedBox(
      height: _dot + 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: _track,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_track),
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              Container(
                height: _track,
                width: width * dotAt,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_track),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.75),
                      scheme.primary,
                    ],
                  ),
                ),
              ),
              // Donde estaba antes de buscar.
              if (target != null)
                Positioned(
                  left: width * _fraction(position) - 1.5,
                  child: Container(
                    width: 3,
                    height: _track + 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              Positioned(
                left: width * dotAt - _dot / 2,
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: target != null ? scheme.primary : Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Destino de la búsqueda, grande en el centro: "1:12:30" y "+2:30".
class MoviePlayerScrubPreview extends StatelessWidget {
  const MoviePlayerScrubPreview({
    super.key,
    required this.target,
    required this.from,
  });

  final Duration target;
  final Duration from;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final delta = target - from;
    return MoaiGlass(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPlayerTime(target),
            style: MoaiText.display(
              context,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                delta.isNegative
                    ? MoaiIcons.vodSkipBack
                    : MoaiIcons.vodSkipForward,
                size: MoaiIconSizes.sm,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                formatPlayerDelta(delta),
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Subtítulo del momento: texto blanco con sombra suave, sin caja, como en
/// los reproductores de TV.
class MoviePlayerSubtitle extends StatelessWidget {
  const MoviePlayerSubtitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // Sin caja: texto blanco con sombra suave (no contorno), que alcanza para
    // leerse sobre imágenes claras.
    return Text(
      text,
      textAlign: TextAlign.center,
      style: MoaiText.body(
        context,
        fontSize: 19,
        height: 1.25,
        color: Colors.white,
      ).copyWith(
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
          Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 14),
        ],
      ),
    );
  }
}

/// Chip central de estado: cargando (con indicador) o en pausa.
class MoviePlayerStatusChip extends StatelessWidget {
  const MoviePlayerStatusChip.loading({super.key}) : paused = false;
  const MoviePlayerStatusChip.paused({super.key}) : paused = true;

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    if (paused) {
      return MoaiGlass(
        borderRadius: 40,
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: Icon(
          MoaiIcons.vodPause,
          size: MoaiIconSizes.xl,
          color: scheme.onSurface,
        ),
      );
    }
    return MoaiGlass(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            LocaleKeys.movies_loading_video.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// El video no se pudo reproducir: qué pasó y qué hacer (OK reintenta desde
/// el mismo punto, atrás vuelve).
class MoviePlayerErrorPanel extends StatelessWidget {
  const MoviePlayerErrorPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hint = MoaiText.body(context, fontSize: 13, color: scheme.onSurface);
    Widget key(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: moaiGlassChipDecoration(scheme, radius: 6),
      child: Text(label, style: hint.copyWith(fontWeight: FontWeight.w800)),
    );

    return MoaiGlass(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MoaiIcons.error, size: MoaiIconSizes.xl, color: scheme.error),
          const SizedBox(height: 10),
          Text(
            LocaleKeys.movies_player_error_title.tr(),
            style: MoaiText.display(
              context,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.movies_player_error_desc.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              key('OK'),
              const SizedBox(width: 6),
              Text(LocaleKeys.movies_player_retry.tr(), style: hint),
              const SizedBox(width: 20),
              Icon(
                MoaiIcons.arrowBack,
                size: MoaiIconSizes.sm,
                color: scheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(LocaleKeys.common_back.tr(), style: hint),
            ],
          ),
        ],
      ),
    );
  }
}
