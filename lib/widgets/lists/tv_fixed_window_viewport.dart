import 'package:flutter/material.dart';

/// Viewport de altura fija para listas/grillas TV por ventana.
///
/// Siempre reserva [slotCount] × [slotExtent] (acotado al alto disponible),
/// anclado abajo del panel (alineado con el tab colapsado) y con el contenido
/// arriba dentro del bloque. Así el header no “salta” si hay menos ítems.
class TvFixedWindowViewport extends StatelessWidget {
  final int slotCount;
  final double slotExtent;
  final Widget child;

  const TvFixedWindowViewport({
    super.key,
    required this.slotCount,
    required this.slotExtent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetHeight =
            (slotCount * slotExtent).clamp(0.0, constraints.maxHeight);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: targetHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
