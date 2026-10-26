part of '../calendar_events_panel.dart';

// El botón del encabezado es [TvWeekHeaderButton] (compartido con
// Descuentos).

/// Escala al pulsar (click o D-pad). Mismo criterio que [TvTile].
class _PressScale extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool pressed;

  const _PressScale({
    required this.child,
    required this.onTap,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: child);
  }
}
