import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Acciones del widget de Arcade, en orden (←/→ las recorren). "Invitar"
/// sólo está con algún amigo conectado.
enum HomeArcadeAction { start, change, invite }

/// Widget de Arcade del Inicio, en franja como [HomeWeatherCard]: el juego
/// cargado y sus acciones: jugar, cambiarlo o invitar a un amigo conectado
/// ([canInvite]). El foco y la acción elegida los maneja el Inicio.
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
    this.canInvite = false,
  });

  /// Hay algún amigo conectado: se ofrece "Invitar".
  final bool canInvite;

  final String romName;

  /// Compañía y año del juego (debajo del nombre), si se conocen.
  final String details;
  final HomeArcadeAction selectedAction;
  final bool isFocused;

  static const double radius = 16;

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFF585EDC);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;

    // REDISEÑO: el cristal de las tarjetas del Inicio, sin halo de color
    // (como el clima). El foco lo marca la acción elegida, no la tarjeta.
    return MoaiGlass(
      borderRadius: radius,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          SizedBox(
            width: HomeCardSummary.width,
            child: HomeCardSummary(
              label: LocaleKeys.home_rail_arcade_title.tr(),
              icon: MoaiIcons.railArcade,
              color: color,
              title: LocaleKeys.arcade_game_ready.tr(),
              line: LocaleKeys.home_arcade_subtitle.tr(),
            ),
          ),
          const HomeCardDivider(margin: EdgeInsets.only(right: 20)),
          // Arriba el juego y su año; abajo las acciones.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  romName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 16,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    HomeGlassButton(
                      icon: MoaiIcons.arcadeActionStartGame,
                      label: LocaleKeys.home_arcade_play.tr(),
                      focused:
                          isFocused && selectedAction == HomeArcadeAction.start,
                    ),
                    const SizedBox(width: 8),
                    HomeGlassButton(
                      icon: MoaiIcons.arcadeActionSelectGame,
                      label: LocaleKeys.home_arcade_change.tr(),
                      focused:
                          isFocused &&
                          selectedAction == HomeArcadeAction.change,
                    ),
                    if (canInvite) ...[
                      const SizedBox(width: 8),
                      HomeGlassButton(
                        icon: MoaiIcons.friends,
                        label: LocaleKeys.home_arcade_invite.tr(),
                        focused:
                            isFocused &&
                            selectedAction == HomeArcadeAction.invite,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
