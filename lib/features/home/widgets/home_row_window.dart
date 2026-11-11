import 'package:flutter/widgets.dart';

/// Ventana de las filas de las tarjetas del Inicio (Eventos, Amigos,
/// Interesantes, Adelantos): cuál es la primera que se ve. Recuerda dónde
/// quedó y sólo se corre si la elegida se sale por un costado, así ←/→ en
/// el medio mueven la selección y no toda la fila.
///
/// [selected] fuera de la lista (sin foco o en un botón de la tarjeta) deja
/// la ventana donde está.
class HomeRowWindow extends StatefulWidget {
  const HomeRowWindow({
    super.key,
    required this.count,
    required this.visible,
    required this.selected,
    required this.builder,
  });

  final int count;

  /// Cuántas entran a la vez.
  final int visible;
  final int selected;

  /// La fila, desde la primera que se ve.
  final Widget Function(int start) builder;

  /// Margen antes de la primera: la mitad de lo que sobra con la fila
  /// llena de tarjetas de [tileWidth] separadas por [gap] en [width]. Con
  /// menos tarjetas la primera queda en el mismo lugar, a la izquierda.
  static double inset({
    required double width,
    required double tileWidth,
    required double gap,
  }) {
    final fit = ((width + gap) ~/ (tileWidth + gap)).clamp(1, 1 << 20);
    final used = fit * tileWidth + (fit - 1) * gap;
    return ((width - used) / 2).clamp(0.0, double.infinity);
  }

  @override
  State<HomeRowWindow> createState() => _HomeRowWindowState();
}

class _HomeRowWindowState extends State<HomeRowWindow> {
  int _start = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    final visible = widget.visible;
    final selected = widget.selected;
    if (selected >= 0 && selected < count) {
      if (selected < _start) {
        _start = selected;
      } else if (selected >= _start + visible) {
        _start = selected - visible + 1;
      }
    }
    // La lista o lo que entra pudo cambiar.
    _start = _start.clamp(0, (count - visible).clamp(0, count));
    return widget.builder(_start);
  }
}
