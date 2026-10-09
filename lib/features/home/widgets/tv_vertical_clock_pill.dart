import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

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
      width: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Cápsula interna para el reloj (Tonal accent, 56x32 matching rail pill size)
          Container(
            width: 56,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hourStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: scheme.onPrimaryContainer,
                      height: 1.0,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _dotsVisible ? 1.0 : 0.2,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: scheme.onPrimaryContainer,
                        height: 1.0,
                      ),
                    ),
                  ),
                  Text(
                    minuteStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Icono del clima animado (Meteocons Lottie vía CDN con fallback seguro)
          Builder(
            builder: (context) {
              final weatherProvider = context.watch<WeatherProvider?>();
              final tempStr = weatherProvider?.temperatureDisplay ?? '33°';
              final lottieUrl = weatherProvider?.lottieUrl ??
                  'https://cdn.jsdelivr.net/npm/@meteocons/lottie@0.1.0/fill/clear-day.json';

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Lottie.network(
                      lottieUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.wb_sunny_outlined,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  //const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      tempStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: scheme.onSurfaceVariant,
                        height: 1.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
