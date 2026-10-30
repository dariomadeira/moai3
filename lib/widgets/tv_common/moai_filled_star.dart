import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Estrella de 5 puntas rellena. La familia de íconos (HugeIcons) sólo trae
/// la de contorno; ésta se dibuja, con las puntas apenas redondeadas para
/// que se vea limpia en tamaños chicos.
class MoaiFilledStar extends StatelessWidget {
  const MoaiFilledStar({super.key, required this.size, required this.color});

  /// Lado del cuadrado que la contiene (de `MoaiIconSizes`).
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _StarPainter(color)),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.48;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      // Arranca arriba (−90°) y alterna punta / valle cada 36°.
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    path.close();
    // Relleno + un trazo fino redondeado: suaviza las puntas sin agrandarla.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * 0.08
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) => oldDelegate.color != color;
}
