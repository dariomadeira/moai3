import 'package:flutter/material.dart';

/// Fila TV por ventana fija (sin ListView/scroll), la versión horizontal de
/// [TvWindowedList]: muestra [windowSize] ítems del mismo ancho y se corre
/// para que el elegido siempre se vea, dejando ver el siguiente.
///
/// No maneja teclas: quien la usa mueve [selectedIndex] con ←/→ (así el foco
/// queda en un solo nodo, como en la grilla de Películas). Con más ítems de
/// los que entran, abajo van unos puntos con la página en la que se está.
class TvWindowedRow<T> extends StatefulWidget {
  const TvWindowedRow({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.itemBuilder,
    required this.windowSize,
    this.gap = 10,
    this.showDots = true,
  });

  final List<T> items;
  final int selectedIndex;
  final int windowSize;

  /// Separación entre ítems.
  final double gap;
  final bool showDots;

  /// [selected]: si es el elegido (quien la usa decide si además tiene foco).
  final Widget Function(BuildContext context, T item, int index, bool selected)
  itemBuilder;

  /// Alto de los puntos con su separación de la fila.
  static const double dotsHeight = _dotsGap + _dotSize;
  static const double _dotsGap = 8;
  static const double _dotSize = 5;

  @override
  State<TvWindowedRow<T>> createState() => TvWindowedRowState<T>();
}

class TvWindowedRowState<T> extends State<TvWindowedRow<T>> {
  int _start = 0;

  /// Primer ítem visible.
  int get windowStart => _start;

  int get _windowSize => widget.windowSize.clamp(1, 64);

  int get pageCount =>
      widget.items.isEmpty ? 0 : (widget.items.length / _windowSize).ceil();

  int get activeDotIndex => pageCount <= 1
      ? 0
      : (widget.selectedIndex ~/ _windowSize).clamp(0, pageCount - 1);

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(covariant TvWindowedRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  /// Corre la ventana lo justo para que el elegido se vea con uno más de
  /// cada lado (si hay).
  void _follow() {
    final count = widget.items.length;
    final size = _windowSize;
    if (count == 0) {
      _start = 0;
      return;
    }
    final selected = widget.selectedIndex.clamp(0, count - 1);
    final lead = size >= 3 ? 1 : 0;
    if (selected > _start + size - 1 - lead) {
      _start = selected - (size - 1 - lead);
    }
    if (selected < _start + lead) _start = selected - lead;
    final maxStart = (count - size).clamp(0, count);
    _start = _start.clamp(0, maxStart);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();
    final size = _windowSize;
    final selected = widget.selectedIndex.clamp(0, count - 1);

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var slot = 0; slot < size; slot++) ...[
          if (slot > 0) SizedBox(width: widget.gap),
          // Los huecos vacíos ocupan su lugar: el ancho de cada ítem no
          // cambia con la cantidad.
          Expanded(
            child: _start + slot < count
                ? KeyedSubtree(
                    key: ValueKey<int>(_start + slot),
                    child: widget.itemBuilder(
                      context,
                      widget.items[_start + slot],
                      _start + slot,
                      _start + slot == selected,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );

    if (!widget.showDots || pageCount <= 1) return row;

    final scheme = Theme.of(context).colorScheme;
    final active = activeDotIndex;
    return Column(
      children: [
        Expanded(child: row),
        const SizedBox(height: TvWindowedRow._dotsGap),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var page = 0; page < pageCount; page++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                // El de la página actual se estira: se lee de lejos.
                width: page == active
                    ? TvWindowedRow._dotSize * 2.4
                    : TvWindowedRow._dotSize,
                height: TvWindowedRow._dotSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TvWindowedRow._dotSize),
                  color: page == active
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
