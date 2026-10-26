import 'dart:async';

import 'package:flutter/material.dart';
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
    final scheme = context.scheme;
    final date =
        '${MoaiFormats.weekdayShort(_time.weekday)} · '
        '${_time.day} ${MoaiFormats.monthShort(_time.month)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          MoaiFormats.time(_time),
          style: MoaiText.display(
            context,
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        Text(
          date,
          style: MoaiText.body(
            context,
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
