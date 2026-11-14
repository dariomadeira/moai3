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

/// Cristal oscuro de las piezas sobre el video: deja ver la película detrás y
/// se lee sobre imágenes claras (sin desenfoque en vivo, como el resto).
BoxDecoration moviePlayerGlassDecoration({double radius = 14}) =>
    moaiVideoGlassDecoration(radius: radius);

/// Texto directo sobre el video: sombra suave para leerse sin caja.
const List<Shadow> _onVideoShadows = [
  Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1)),
];

/// Arriba, sin panel: el título sobre el oscurecido y, a la derecha, las
/// etiquetas de calidad y audio.
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.display(
              context,
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ).copyWith(shadows: _onVideoShadows),
          ),
        ),
        const SizedBox(width: 12),
        if (quality.isNotEmpty) ...[
          _Chip(icon: MoaiIcons.vodQuality, label: quality),
          const SizedBox(width: 8),
        ],
        _Chip(icon: MoaiIcons.vodAudio, label: audio),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: moviePlayerGlassDecoration(radius: 999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoaiIconSizes.xs, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: MoaiText.body(context, fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Qué se puede cambiar durante la película.
enum MoviePlayerMenu { audio, subtitles, size }

/// Abajo, sin panel: tiempo, barra fina, tiempo restante y, debajo, las
/// píldoras de audio y subtítulos ([menus]; [selectedMenu] es la elegida).
class MoviePlayerBottomBar extends StatelessWidget {
  const MoviePlayerBottomBar({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    this.scrubTarget,
    this.menus = const [],
    this.selectedMenu,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;

  /// Destino de la búsqueda en curso (todavía sin saltar).
  final Duration? scrubTarget;

  final List<MoviePlayerMenu> menus;
  final MoviePlayerMenu? selectedMenu;

  /// Alto de la fila de píldoras: el menú abierto se apoya encima.
  static const double menuRowHeight = 36;

  @override
  Widget build(BuildContext context) {
    final shown = scrubTarget ?? position;
    final remaining = duration > shown ? duration - shown : Duration.zero;
    final timeStyle = MoaiText.body(
      context,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ).copyWith(shadows: _onVideoShadows);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              isPlaying ? MoaiIcons.vodPlay : MoaiIcons.vodPause,
              size: MoaiIconSizes.sm,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
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
              width: 68,
              child: Text(
                duration > Duration.zero
                    ? '−${formatPlayerTime(remaining)}'
                    : '',
                textAlign: TextAlign.right,
                style: timeStyle.copyWith(
                  color: const Color(0xCCFFFFFF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (menus.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: menuRowHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final menu in menus) ...[
                  if (menu != menus.first) const SizedBox(width: 8),
                  _MenuPill(menu: menu, selected: menu == selectedMenu),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MenuPill extends StatelessWidget {
  const _MenuPill({required this.menu, required this.selected});

  final MoviePlayerMenu menu;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final (icon, label) = switch (menu) {
      MoviePlayerMenu.audio => (
        MoaiIcons.vodAudio,
        LocaleKeys.movies_player_menu_audio,
      ),
      MoviePlayerMenu.subtitles => (
        MoaiIcons.vodSubtitles,
        LocaleKeys.settings_movies_subtitles,
      ),
      MoviePlayerMenu.size => (
        MoaiIcons.vodSubtitleSize,
        LocaleKeys.movies_player_menu_size,
      ),
    };
    final color = selected ? scheme.onPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: selected
          ? BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
            )
          : moviePlayerGlassDecoration(radius: 999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoaiIconSizes.xs, color: color),
          const SizedBox(width: 6),
          Text(
            label.tr(),
            style: MoaiText.body(context, fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

/// Las respuestas del cartel de recomendar, en orden en pantalla.
enum MovieRecommendAnswer { yes, no, cancel }

/// Cartel de los últimos minutos (SPEC-51): chico, en una esquina y sin
/// pausar. [selected] es la respuesta elegida con ←/→.
class MovieRecommendPrompt extends StatelessWidget {
  const MovieRecommendPrompt({super.key, required this.selected, this.prompt});

  final MovieRecommendAnswer selected;

  /// La pregunta; por defecto la de películas (las series dicen la
  /// temporada que se terminó).
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    Widget pill(MovieRecommendAnswer answer, IconData? icon, String label) {
      final isSelected = answer == selected;
      final color = isSelected ? scheme.onPrimary : Colors.white;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: isSelected
            ? BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(999),
              )
            : moviePlayerGlassDecoration(radius: 999),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: MoaiIconSizes.xs, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: MoaiText.body(context, fontSize: 12, color: color),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: moviePlayerGlassDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            prompt ?? LocaleKeys.movies_recommend_prompt.tr(),
            style: MoaiText.body(context, fontSize: 13, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pill(
                MovieRecommendAnswer.yes,
                MoaiIcons.vodRecommend,
                LocaleKeys.movies_recommend_yes.tr(),
              ),
              const SizedBox(width: 8),
              pill(
                MovieRecommendAnswer.no,
                MoaiIcons.vodNotRecommend,
                LocaleKeys.movies_recommend_no.tr(),
              ),
              const SizedBox(width: 8),
              pill(
                MovieRecommendAnswer.cancel,
                null,
                LocaleKeys.common_cancel.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una opción del menú abierto; [current] es la que está en uso.
class MoviePlayerMenuOption {
  const MoviePlayerMenuOption(this.label, {this.current = false});

  final String label;
  final bool current;
}

/// Menú chico sobre las píldoras: la película sigue a la vista. [focused] es
/// la opción elegida; si no entran todas, corre la ventana.
class MoviePlayerMenuPanel extends StatelessWidget {
  const MoviePlayerMenuPanel({
    super.key,
    required this.options,
    required this.focused,
  });

  final List<MoviePlayerMenuOption> options;
  final int focused;

  static const int _maxVisible = 6;
  static const double width = 200;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final count = options.length.clamp(0, _maxVisible);
    final start = (focused - count + 1).clamp(0, options.length - count);
    return Container(
      width: width,
      padding: const EdgeInsets.all(5),
      decoration: moviePlayerGlassDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = start; i < start + count; i++)
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: i == focused ? scheme.primary : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      options[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        fontSize: 13,
                        color: i == focused ? scheme.onPrimary : Colors.white,
                      ),
                    ),
                  ),
                  if (options[i].current)
                    Icon(
                      MoaiIcons.check,
                      size: MoaiIconSizes.xs,
                      color: i == focused ? scheme.onPrimary : Colors.white,
                    ),
                ],
              ),
            ),
        ],
      ),
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

  static const double _track = 4;
  static const double _dot = 12;

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
                  color: Colors.white.withValues(alpha: 0.28),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: moviePlayerGlassDecoration(radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatPlayerTime(target),
            style: MoaiText.display(
              context,
              fontSize: 26,
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
  const MoviePlayerSubtitle({
    super.key,
    required this.text,
    this.fontSize = 19,
  });

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    // Sin caja: texto blanco con sombra suave (no contorno), que alcanza para
    // leerse sobre imágenes claras.
    return Text(
      text,
      textAlign: TextAlign.center,
      style:
          MoaiText.body(
            context,
            fontSize: fontSize,
            height: 1.25,
            color: Colors.white,
          ).copyWith(
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.85),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 14,
              ),
            ],
          ),
    );
  }
}

/// Chip central de estado: cargando (con indicador) o en pausa.
class MoviePlayerStatusChip extends StatelessWidget {
  /// [label] reemplaza al "Cargando…" (p. ej. "Siguiente: Capítulo 6").
  const MoviePlayerStatusChip.loading({super.key, this.label}) : paused = false;
  const MoviePlayerStatusChip.paused({super.key}) : paused = true, label = null;

  final bool paused;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    if (paused) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: moviePlayerGlassDecoration(radius: 28),
        child: const Icon(
          MoaiIcons.vodPause,
          size: MoaiIconSizes.lg,
          color: Colors.white,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: moviePlayerGlassDecoration(radius: 999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              // Gris claro: va sobre el cristal oscuro del reproductor.
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label ?? LocaleKeys.movies_loading_video.tr(),
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
      child: Text(label, style: hint.copyWith(fontWeight: FontWeight.w700)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      decoration: moviePlayerGlassDecoration(radius: 22),
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
