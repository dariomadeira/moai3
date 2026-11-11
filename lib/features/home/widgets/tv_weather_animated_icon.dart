import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Icono animado del clima para Smart TV.
///
/// Reproduce exactamente 1 ciclo de animación Lottie (a 30 FPS) cuando:
/// 1. Se monta o se descarga la composición por primera vez.
/// 2. Cambia la condición meteorológica ([lottieAsset]).
/// 3. Se actualizan los datos de clima ([updateToken]).
///
/// Al concluir el ciclo, la animación se congela en el fotograma final y el
/// [AnimationController] detiene el `Ticker` de Flutter por completo,
/// reduciendo el consumo de CPU/GPU al 0% absoluto durante el reposo.
class TvWeatherAnimatedIcon extends StatefulWidget {
  /// El ícono, de `assets/lottie/weather/` ([WeatherIconMapper]).
  final String lottieAsset;
  final Object? updateToken;
  final double size;

  /// Sin animar: se muestra quieto en el fotograma final (el mismo en que
  /// queda el animado). Para los íconos chicos de la tira de horas, que no
  /// necesitan moverse: ahorra el ciclo de cada uno al cargar.
  final bool animate;

  const TvWeatherAnimatedIcon({
    super.key,
    required this.lottieAsset,
    this.updateToken,
    this.size = 34,
    this.animate = true,
  });

  @override
  State<TvWeatherAnimatedIcon> createState() => _TvWeatherAnimatedIconState();
}

class _TvWeatherAnimatedIconState extends State<TvWeatherAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  LottieComposition? _composition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant TvWeatherAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lottieAsset != widget.lottieAsset) {
      // Si cambió el ícono, se reseteará la composición y onLoaded la reproducirá
      _composition = null;
    } else if (oldWidget.updateToken != widget.updateToken) {
      // Mismo tipo de clima, pero se refrescaron los datos: reproducir 1 ciclo
      _replayOnce();
    }
  }

  void _replayOnce() {
    if (_composition != null && mounted) {
      _play();
    }
  }

  /// Un ciclo o, sin [TvWeatherAnimatedIcon.animate], directo al final.
  void _play() {
    if (widget.animate) {
      _controller.forward(from: 0.0);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      // Ya recoloreado en el asset (tool/build_weather_icons.dart).
      child: Lottie.asset(
        widget.lottieAsset,
        controller: _controller,
        repeat: false,
        fit: BoxFit.contain,
        frameRate: const FrameRate(30),
        onLoaded: (composition) {
          _composition = composition;
          _controller.duration = composition.duration;
          if (mounted) _play();
        },
        errorBuilder: (context, error, stackTrace) => Icon(
          MoaiIcons.weatherFallback,
          size: widget.size * 0.6,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
