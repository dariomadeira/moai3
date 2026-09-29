import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/theme/moai_text.dart';

/// Reloj tipográfico para la barra superior TV (sin píldora ni icono).
///
/// Alineado simétricamente con [TvTabBar]:
/// - Altura total: 64 dp (padding vertical 12 + altura 40).
/// - Tipografía limpia en `scheme.onSurface` con cifras tabulares.
/// - Separador de dos puntos con parpadeo suave animado cada segundo.
class TvClockPill extends StatefulWidget {
  const TvClockPill({super.key});

  @override
  State<TvClockPill> createState() => _TvClockPillState();
}

class _TvClockPillState extends State<TvClockPill> {
  late DateTime _now;
  bool _colonVisible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _colonVisible = !_colonVisible;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hours = _now.hour.toString().padLeft(2, '0');
    final minutes = _now.minute.toString().padLeft(2, '0');

    final digitStyle = MoaiText.display(
      context,
      color: scheme.onSurface,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    ).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return ExcludeFocus(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 12,
          bottom: 12,
          right: TvLayoutConstants.viewerHorizontalPaddingEnd,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(hours, style: digitStyle),
              AnimatedOpacity(
                opacity: _colonVisible ? 1.0 : 0.15,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Text(':', style: digitStyle),
                ),
              ),
              Text(minutes, style: digitStyle),
            ],
          ),
        ),
      ),
    );
  }
}
