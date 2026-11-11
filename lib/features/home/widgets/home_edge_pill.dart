import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Flecha de un costado de las filas de las tarjetas del Inicio (Eventos,
/// Amigos, Interesantes, Adelantos). REDISEÑO: una "pill" vertical que se
/// ve siempre: si hay más de ese lado, como un botón con foco (el acento);
/// si no, de vidrio blanco como los botones sin foco, con la flecha gris.
class HomeEdgePill extends StatelessWidget {
  const HomeEdgePill({super.key, required this.icon, required this.active});

  /// Lugar que ocupa en la fila (la pill va centrada adentro).
  static const double width = 28;

  static const double _pillWidth = 20;
  static const double _pillHeight = 36;

  final IconData icon;

  /// Hay más de ese lado (se puede correr).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: width,
      child: Center(
        // Sin animación ni brillo: el cambio de vidrio a acento no
        // parpadea al moverse.
        child: Container(
          width: _pillWidth,
          height: _pillHeight,
          decoration: moaiGlassButtonDecoration(
            scheme,
            focused: active,
            radius: _pillWidth / 2,
          ).copyWith(boxShadow: const []),
          child: Icon(
            icon,
            size: MoaiIconSizes.sm,
            color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
