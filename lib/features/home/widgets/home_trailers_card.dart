import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_movie_strip.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Widget "Adelantos" del Inicio, como "Seguir viendo": a la izquierda
/// el resumen y a la derecha los adelantos en fila (trailers de YouTube de
/// los estrenos, de TMDb: `HomeTrailersProvider`).
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

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFFC026D3);

  @override
  Widget build(BuildContext context) {
    final count = trailers.length;
    final countLabel = count == 1
        ? LocaleKeys.home_trailers_count_one.tr()
        : LocaleKeys.home_trailers_count.tr(namedArgs: {'count': '$count'});

    // REDISEÑO: el cristal de las tarjetas del Inicio, sin halo de color
    // (como Arcade). El foco lo lleva el adelanto elegido, no la tarjeta.
    return MoaiGlass(
      borderRadius: radius,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: HomeCardSummary.width,
            child: HomeCardSummary(
              label: LocaleKeys.home_rail_movies_title.tr(),
              icon: MoaiIcons.vodTrailer,
              color: color,
              title: LocaleKeys.home_trailers_title.tr(),
              line: isFocused ? LocaleKeys.home_trailers_hint.tr() : countLabel,
            ),
          ),
          const HomeCardDivider(margin: EdgeInsets.only(right: 20)),
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
