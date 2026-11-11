import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tag chico de estado ("EN VIVO", "FIN", "PRÓX"): el degradé de un botón
/// con foco en [color], con un brillo suave. Es el de la tarjeta de eventos
/// del Inicio; la Agenda lo usa con un color por estado.
class MoaiStatusTag extends StatelessWidget {
  const MoaiStatusTag({
    super.key,
    required this.label,
    required this.color,
    this.large = false,
  });

  final String label;
  final Color color;

  /// Más grande, para un encabezado (p. ej. el paso de un diálogo); el
  /// mismo tag que en las tarjetas.
  final bool large;

  /// En vivo (el de la tarjeta de eventos del Inicio).
  static const Color liveColor = Color(0xFF9D1933);

  /// Terminado: gris pizarra, que no compite con lo que viene.
  static const Color finishedColor = Color(0xFF64748B);

  /// Por empezar (hoy): verde azulado.
  static const Color soonColor = Color(0xFF0F8A7E);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: large ? 24 : 18,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(large ? 12 : 9),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6),
        ],
      ),
      child: Text(
        label,
        style: MoaiText.body(
          context,
          color: Colors.white,
          fontSize: large ? 10.5 : 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
