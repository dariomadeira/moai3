import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/features/home/widgets/home_movie_strip.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Tarjeta de películas del Inicio ("Interesantes", "Seguir viendo"), en
/// franja como Eventos: a la izquierda el resumen (título, cuántas hay o la
/// ayuda, y un botón de acción para todas) y a la derecha las películas.
///
/// El foco y la selección los maneja el Inicio: [selectedIndex] es la
/// película elegida o [actionIndex] para el botón (a la izquierda de la
/// primera).
class HomeMovieListCard extends StatelessWidget {
  const HomeMovieListCard({
    super.key,
    required this.icon,
    required this.glow,
    required this.title,
    required this.countLabel,
    required this.hint,
    required this.actionIcon,
    required this.actionLabel,
    required this.movies,
    required this.selectedIndex,
    this.isFocused = false,
    this.watched = const {},
    this.emptyText,
    this.loadingId,
  });

  /// Película que se está abriendo (`contentId`): muestra que carga.
  final String? loadingId;

  final IconData icon;

  /// Color del halo de la tarjeta ([HomeCardColors]).
  final Color glow;
  final String title;

  /// "3 películas"; con una película enfocada se ve [hint] en su lugar.
  final String countLabel;
  final String hint;

  /// Botón para todas ("Quitar todas", "Marcar todo como visto").
  final IconData actionIcon;
  final String actionLabel;

  final List<MovieItem> movies;
  final int selectedIndex;
  final bool isFocused;

  /// Cuánto se vio de cada una (0–1, por `contentId`): barra en la miniatura.
  final Map<String, double> watched;

  /// Sin películas: qué hacer para tenerlas.
  final String? emptyText;

  /// [selectedIndex] del botón de acción.
  static const int actionIndex = -1;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return HomeCard(
      glow: glow,
      // Con películas el foco lo lleva la elegida, no la tarjeta.
      focused: isFocused && movies.isEmpty,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 214,
            child: _Summary(
              icon: icon,
              title: title,
              // El aviso va con una película enfocada, no con el botón.
              line: isFocused && selectedIndex != actionIndex
                  ? hint
                  : countLabel,
              highlightLine: isFocused && selectedIndex != actionIndex,
              showAction: movies.isNotEmpty,
              actionIcon: actionIcon,
              actionLabel: actionLabel,
              actionFocused: isFocused && selectedIndex == actionIndex,
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 16),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: movies.isEmpty
                ? _Empty(text: emptyText ?? '')
                : HomeMovieStrip(
                    movies: movies,
                    selectedIndex: selectedIndex,
                    isFocused: isFocused,
                    watched: watched,
                    loadingId: loadingId,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Título, una línea (cuántas hay o la ayuda) y el botón de acción.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.icon,
    required this.title,
    required this.line,
    required this.highlightLine,
    required this.showAction,
    required this.actionIcon,
    required this.actionLabel,
    required this.actionFocused,
  });

  final IconData icon;
  final String title;
  final String line;
  final bool highlightLine;
  final bool showAction;
  final IconData actionIcon;
  final String actionLabel;
  final bool actionFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: MoaiIconSizes.lg, color: scheme.primary),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
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
        if (showAction) ...[
          const SizedBox(height: 2),
          Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: highlightLine ? scheme.primary : scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _ActionButton(
            icon: actionIcon,
            label: actionLabel,
            isFocused: actionFocused,
          ),
        ],
      ],
    );
  }
}

/// Botón chico de cristal, como el de Suscripciones en Eventos; con foco se
/// llena del acento.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isFocused,
  });

  final IconData icon;
  final String label;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fg = isFocused ? scheme.onPrimary : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: moaiGlassButtonDecoration(
        scheme,
        focused: isFocused,
        radius: 16,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: MoaiIconSizes.sm,
            color: isFocused ? scheme.onPrimary : scheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.body(
                context,
                color: fg,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Todavía no hay ninguna: qué hacer para tenerlas.
class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: MoaiText.body(
          context,
          color: context.scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
    );
  }
}
