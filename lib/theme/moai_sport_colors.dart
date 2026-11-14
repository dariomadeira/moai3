import 'package:flutter/material.dart';

/// REDISEÑO: un color por deporte para su ícono (se lee de un vistazo qué
/// es cada evento). La clave es el id de la suscripción de Agenda; el ícono
/// de cada una está en `MoaiIcons.calendarSubIconFor`.
abstract final class MoaiSportColors {
  static const Map<String, Color> bySubscription = {
    'f1': Color(0xFFE10600), // rojo F1
    'lpf_ar': Color(0xFF2E8BC9), // celeste
    'champions': Color(0xFF1E3A8A), // azul noche
    'premier': Color(0xFF7B2CBF), // violeta
    'nfl': Color(0xFF15803D), // verde cancha
    'nba': Color(0xFFE8590C), // naranja pelota
  };

  /// Color del ícono de un deporte; sin uno propio, [fallback] (el acento).
  static Color of(String subscriptionId, Color fallback) =>
      bySubscription[subscriptionId] ?? fallback;
}
