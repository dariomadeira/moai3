import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Acciones del widget de Arcade, en orden (←/→ las recorren).
enum HomeArcadeAction { start, change }

/// Widget de Arcade del Inicio, en franja como [HomeWeatherCard]: el juego
/// cargado y dos acciones, encenderlo o cambiarlo. El foco y la acción
/// elegida los maneja el Inicio.
///
/// Sólo se muestra con el Arcade instalado y una ROM activa; eso lo decide
/// el Inicio.
class HomeArcadeCard extends StatelessWidget {
  const HomeArcadeCard({
    super.key,
    required this.romName,
    this.details = '',
    this.selectedAction = HomeArcadeAction.start,
    this.isFocused = false,
  });

  final String romName;

  /// Compañía y año del juego, si se conocen.
  final String details;
  final HomeArcadeAction selectedAction;
  final bool isFocused;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;

    return MoaiGlass(
      borderRadius: radius,
      elevated: false,
      solid: true,
      // El foco lo marca la acción elegida, no la tarjeta (como en Eventos).
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          // Mismo bloque de resumen que Clima y Eventos.
          SizedBox(
            width: 214,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.home_rail_arcade_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: muted,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      MoaiIcons.railArcade,
                      size: MoaiIconSizes.xl,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        LocaleKeys.arcade_game_ready.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.display(
                          context,
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 20),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          // El nombre usa hasta dos líneas para no cortarse.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  romName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ActionButton(
            icon: MoaiIcons.arcadeActionStartGame,
            label: LocaleKeys.arcade_action_start_game.tr(),
            focused: isFocused && selectedAction == HomeArcadeAction.start,
          ),
          const SizedBox(width: 10),
          _ActionButton(
            icon: MoaiIcons.arcadeActionSelectGame,
            label: LocaleKeys.home_arcade_change_game.tr(),
            focused: isFocused && selectedAction == HomeArcadeAction.change,
          ),
        ],
      ),
    );
  }
}

/// Botón de cristal de la tarjeta: con foco, acento con brillo y halo.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.focused,
  });

  final IconData icon;
  final String label;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: moaiGlassButtonDecoration(scheme, focused: focused),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: MoaiIconSizes.md,
            color: focused ? scheme.onPrimary : scheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: MoaiText.body(
              context,
              color: focused ? scheme.onPrimary : scheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
