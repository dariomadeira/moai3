import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';

// Componentes guardados de la tarjeta grande de eventos del Inicio (sacada
// el 2026-11-02): la tarjeta de un evento con la foto de su tipo, para
// reusarla en una fila ([TvWindowedRow]) o donde haga falta.

/// Imagen de fondo de cada tipo de evento: `assets/images/events/<id>.webp`
/// con el id de la suscripción (`f1`, `nfl`…); si no hay, la genérica.
///
/// Medida: 288×330 (la tarjeta mide ~122×140 puntos en el TV, ~244×280 px a
/// densidad 2). El texto va abajo sobre un degradado oscuro (~40 % de
/// abajo) y la competición arriba a la izquierda: lo importante, al centro.
abstract final class EventArtwork {
  static const String folder = 'assets/images/events/';
  static const String fallback = '${folder}default.webp';

  /// La del tipo; si el archivo no existe, la tarjeta usa [fallback].
  static String pathFor(String subscriptionId) => '$folder$subscriptionId.webp';
}

/// Un evento con la imagen de su tipo de fondo (estilo de las tarjetas de
/// películas de referencia): la competición en una pastilla arriba, "En
/// vivo" si está en curso, y abajo, sobre un degradado oscuro, el título y
/// la hora.
class HomeEventTile extends StatelessWidget {
  const HomeEventTile({
    super.key,
    required this.event,
    required this.artwork,
    this.isFocused = false,
  });

  final CalendarEvent event;

  /// Asset de la imagen de fondo (ver [EventArtwork]).
  final String artwork;
  final bool isFocused;

  static const double radius = 12;

  /// Nombre corto de la competición por suscripción: la pastilla es chica y
  /// "Liga Profesional Argentina" no entra.
  static const Map<String, String> _shortTags = {
    'lpf_ar': 'LPF',
    'champions': 'Champions',
    'premier': 'Premier',
  };

  /// La etiqueta de la pastilla: la corta si hay; si no, la competición sola
  /// (la de F1 trae el circuito: "F1 · Autódromo…").
  static String shortTag(CalendarEvent event) =>
      _shortTags[event.subscriptionId] ??
      event.competition.split(' · ').first.trim();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = event.status == CalendarEventStatus.live;
    final tag = shortTag(event);
    final borderRadius = BorderRadius.circular(radius);

    return LayoutBuilder(
      builder: (context, constraints) {
        // La imagen se decodifica al ancho de la tarjeta, no al del archivo.
        final decodeWidth =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .ceil();
        return DecoratedBox(
          // Borde por encima: con foco crece sin mover el contenido.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: isFocused
                  ? scheme.primary
                  : Colors.white.withValues(alpha: 0.35),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  artwork,
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidth > 0 ? decodeWidth : null,
                  gaplessPlayback: true,
                  // Sin imagen para este tipo: la genérica.
                  errorBuilder: (_, _, _) => Image.asset(
                    EventArtwork.fallback,
                    fit: BoxFit.cover,
                    cacheWidth: decodeWidth > 0 ? decodeWidth : null,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFF1B1E24)),
                  ),
                ),
                // Oscuro abajo para que el texto blanco se lea sobre
                // cualquier imagen.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xD9000000)],
                      stops: [0.3, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLive)
                        const Align(
                          alignment: Alignment.topRight,
                          child: _LiveDot(),
                        ),
                      const Spacer(),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: Colors.white,
                          fontSize: 10.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Abajo de todo: la hora a la izquierda y la
                      // competición a la derecha, con el botón de vidrio de
                      // la tarjeta destacada de películas.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isLive
                                  ? LocaleKeys.calendar_status_live.tr()
                                  : event.formattedTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MoaiText.body(
                                context,
                                color: const Color(0xC7FFFFFF),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (tag.isNotEmpty)
                            MoaiPillButton(
                              kind: MoaiPillButtonKind.glass,
                              size: 18,
                              label: tag,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Punto rojo de "en vivo".
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFFFF3B30),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x80FF3B30), blurRadius: 6)],
      ),
    );
  }
}
