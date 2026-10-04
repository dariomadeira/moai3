import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moai3/theme/moai_text.dart';

/// Componente de reloj en formato Cápsula (Pill) Vertical.
///
/// Muestra las horas arriba, los dos puntos en el centro y los minutos abajo,
/// diseñado para integrarse armoniosamente sobre el botón de Ajustes en la barra lateral TV.
class TvVerticalClockPill extends StatefulWidget {
  const TvVerticalClockPill({super.key});

  @override
  State<TvVerticalClockPill> createState() => _TvVerticalClockPillState();
}

class _TvVerticalClockPillState extends State<TvVerticalClockPill> {
  late Timer _timer;
  late DateTime _now;
  bool _dotsVisible = true;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    // Actualiza cada segundo para el parpadeo suave de los dos puntos
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _dotsVisible = !_dotsVisible;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hourStr = DateFormat('HH').format(_now);
    final minuteStr = DateFormat('mm').format(_now);

    return Container(
      width: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cápsula interna para el reloj (Tonal accent)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hourStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: scheme.onPrimaryContainer,
                    height: 1.0,
                  ),
                ),
                // Padding(
                //   padding: const EdgeInsets.symmetric(vertical: 3),
                //   child: AnimatedOpacity(
                //     opacity: _dotsVisible ? 1.0 : 0.15,
                //     duration: const Duration(milliseconds: 300),
                //     curve: Curves.easeInOut,
                //     child: Row(
                //       mainAxisSize: MainAxisSize.min,
                //       mainAxisAlignment: MainAxisAlignment.center,
                //       children: [
                //         Container(
                //           width: 3,
                //           height: 3,
                //           decoration: BoxDecoration(
                //             color: scheme.onPrimaryContainer,
                //             shape: BoxShape.circle,
                //           ),
                //         ),
                //         const SizedBox(width: 3),
                //         Container(
                //           width: 3,
                //           height: 3,
                //           decoration: BoxDecoration(
                //             color: scheme.onPrimaryContainer,
                //             shape: BoxShape.circle,
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                const SizedBox(height: 3),
                Text(
                  minuteStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.5),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Temperatura (hardcodeada)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "33°",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: scheme.onSurfaceVariant,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
