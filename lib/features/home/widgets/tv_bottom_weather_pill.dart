import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moai3/features/home/widgets/tv_weather_animated_icon.dart';
import 'package:moai3/state/weather_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

/// Cápsula de hora y clima en la parte superior del rail lateral.
class TvBottomWeatherPill extends StatefulWidget {
  const TvBottomWeatherPill({super.key});

  @override
  State<TvBottomWeatherPill> createState() => _TvBottomWeatherPillState();
}

class _TvBottomWeatherPillState extends State<TvBottomWeatherPill> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.minute != _now.minute) {
        setState(() => _now = now);
      }
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

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.48);

    return RepaintBoundary(
      child: Container(
        width: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Cápsula interna para la hora (dos puntos fijos sin AnimatedOpacity)
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2),
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
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: scheme.onPrimaryContainer,
                        height: 1.0,
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
          // Icono del clima animado (1 ciclo en actualización + congelado estático)
          Builder(
            builder: (context) {
              final weatherProvider = context.watch<WeatherProvider?>();
              final tempStr = weatherProvider?.temperatureDisplay ?? '33°';
              final lottieUrl =
                  weatherProvider?.lottieUrl ??
                  'https://cdn.jsdelivr.net/npm/@meteocons/lottie@0.1.0/fill/clear-day.json';
              final updateToken =
                  weatherProvider?.weather?.lastUpdated.millisecondsSinceEpoch;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvWeatherAnimatedIcon(
                    lottieUrl: lottieUrl,
                    updateToken: updateToken,
                    size: 34,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
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
    ),
  );
}
}
