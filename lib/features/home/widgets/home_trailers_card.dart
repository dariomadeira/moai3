import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/features/home/widgets/home_movie_strip.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Widget "Adelantos" del Inicio, como [HomeWatchlistCard]: a la izquierda
/// el resumen y a la derecha los adelantos del catálogo en fila (en la
/// grilla de Películas ya no aparecen).
///
/// El foco y la selección los maneja el Inicio: [selectedIndex] es el
/// adelanto elegido (←/→ lo mueven, OK abre su detalle). Sólo se muestra si
/// hay adelantos; eso lo decide el Inicio.
class HomeTrailersCard extends StatelessWidget {
  const HomeTrailersCard({
    super.key,
    required this.trailers,
    required this.selectedIndex,
    this.isFocused = false,
  });

  final List<MovieItem> trailers;
  final int selectedIndex;
  final bool isFocused;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;
    final count = trailers.length;
    final countLabel = count == 1
        ? LocaleKeys.home_trailers_count_one.tr()
        : LocaleKeys.home_trailers_count.tr(namedArgs: {'count': '$count'});

    return HomeCard(
      glow: HomeCardColors.trailers,
      // El foco lo lleva el adelanto elegido, no la tarjeta.
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 214,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      MoaiIcons.vodTrailer,
                      size: MoaiIconSizes.lg,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        LocaleKeys.home_trailers_title.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.display(
                          context,
                          color: scheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isFocused ? LocaleKeys.home_trailers_hint.tr() : countLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: isFocused ? scheme.primary : muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 16),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: HomeMovieStrip(
              movies: trailers,
              selectedIndex: selectedIndex,
              isFocused: isFocused,
            ),
          ),
        ],
      ),
    );
  }
}
