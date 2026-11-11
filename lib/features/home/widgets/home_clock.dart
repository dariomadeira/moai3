import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/utils/moai_formats.dart';

/// Hora y fecha del Inicio, a la derecha del saludo (el reloj del rail no
/// se ve en el Inicio).
///
/// Hora del aparato, como el reloj del rail. Se redibuja sólo ella, una vez
/// por minuto, justo cuando cambia.
class HomeClock extends StatefulWidget {
  const HomeClock({super.key, this.now});

  /// Hora fija (tests); sin ella, la del aparato.
  final DateTime Function()? now;

  /// El degradado de la hora, para lo que va "como la hora del Inicio" (los
  /// títulos de los paneles, el de la semana de la Agenda…). Va del tinta
  /// del saludo al color de acento ([setAccent]), que se oscurece para que el
  /// final del título se lea sobre el cristal claro.
  ///
  /// Es un getter: con otro acento devuelve otra función, así los títulos ya
  /// dibujados se repintan al reconstruirse (con la misma, [ShaderMask] no
  /// repinta).
  static ShaderCallback get timeShader => _timeShader;
  static ShaderCallback _timeShader = _shaderFor(_defaultAccent);

  static const Color _defaultAccent = Color(0xFF2B4CFF);
  static Color _accent = _defaultAccent;
  static bool _dark = false;

  /// Lo llama la app con el color de acento elegido y el modo: en el
  /// oscuro ([dark]) el degradado va de casi blanco al acento aclarado.
  static void setAccent(Color accent, {bool dark = false}) {
    if (accent == _accent && dark == _dark) return;
    _accent = accent;
    _dark = dark;
    _timeShader = dark ? _darkShaderFor(accent) : _shaderFor(accent);
  }

  /// Modo oscuro (2026-11-10): el mismo recorrido de noche, de casi blanco
  /// al acento aclarado (sobre el cristal ahumado el oscuro no se lee).
  static ShaderCallback _darkShaderFor(Color accent) {
    final gradient = LinearGradient(
      begin: const Alignment(-1, -0.18),
      end: const Alignment(1, 0.18),
      colors: [
        const Color(0xFFF3F4F8),
        Color.lerp(accent, Colors.white, 0.55)!,
        Color.lerp(accent, Colors.white, 0.3)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    return gradient.createShader;
  }

  static ShaderCallback _shaderFor(Color accent) {
    // Con el azul por defecto da casi los tonos de antes (#1C2A5E y
    // #2B4CC8). Un acento claro (coral, cian) se oscurece un poco más.
    final light =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light;
    final gradient = LinearGradient(
      begin: const Alignment(-1, -0.18),
      end: const Alignment(1, 0.18),
      colors: [
        const Color(0xFF141812),
        Color.lerp(accent, Colors.black, 0.63)!,
        Color.lerp(accent, Colors.black, light ? 0.32 : 0.2)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    return gradient.createShader;
  }

  @override
  State<HomeClock> createState() => _HomeClockState();
}

class _HomeClockState extends State<HomeClock> {
  late DateTime _time = _read();
  Timer? _timer;

  DateTime _read() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _scheduleNextMinute();
  }

  void _scheduleNextMinute() {
    final now = _read();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() => _time = _read());
      _scheduleNextMinute();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${MoaiFormats.weekdayShort(_time.weekday)} · '
        '${_time.day} ${MoaiFormats.monthShort(_time.month)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // El degradado se estira sobre la hora misma (el shader de un
        // foreground va en coordenadas de la capa, no del texto). Es una
        // zona chica que cambia una vez por minuto: aislada, no repinta más.
        RepaintBoundary(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: HomeClock.timeShader,
            child: Text(
              MoaiFormats.time(_time),
              style: MoaiText.display(
                context,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ),
        Text(
          date,
          style: MoaiText.body(
            context,
            // REDISEÑO: mismo color que el subtítulo del saludo.
            color: MoaiPalette.of(context).inkSoft,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
