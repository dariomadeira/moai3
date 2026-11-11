import 'package:flutter/material.dart';

/// Contador (eventos de hoy en el rail, eventos del día en la Agenda): el
/// degradado del botón con foco (`moaiGlassButtonDecoration`), sin el aura,
/// en naranja para que no se confunda con el acento.
class MoaiCountBadge extends StatelessWidget {
  const MoaiCountBadge({super.key, required this.count, this.size = 16});

  final int count;

  /// Alto (y ancho mínimo); el número y el relleno crecen con él. 16 en el
  /// rail y la Agenda; más grande en las pestañas del modal de amigos.
  final double size;

  static const Color color = Color(0xFFFF8A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      padding: EdgeInsets.symmetric(horizontal: size / 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 9 / 16,
          height: 1,
        ),
      ),
    );
  }
}
