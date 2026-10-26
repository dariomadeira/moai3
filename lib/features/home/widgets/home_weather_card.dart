import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/features/home/widgets/home_sky.dart';
import 'package:moai3/features/home/widgets/tv_weather_animated_icon.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/services/weather_icon_mapper.dart';
import 'package:moai3/services/weather_service.dart';
import 'package:moai3/theme/moai_text.dart';

/// Widget de clima del Inicio, en formato franja para la lista de widgets
/// (doble alto que un ítem de Ajustes, todo el ancho del panel):
/// estado actual a la izquierda, próximas horas con la curva de temperatura
/// al centro y el ícono con su halo a la derecha.
class HomeWeatherCard extends StatelessWidget {
  const HomeWeatherCard({
    super.key,
    required this.weather,
    required this.now,
    this.isFocused = false,
    this.place,
  });

  /// Dónde es el clima (ver `WeatherProvider.placeName`); sin él, la
  /// localidad que devolvió el servicio.
  final String? place;

  final WeatherData weather;

  /// Hora de referencia para elegir las próximas horas (la refresca el Inicio).
  final DateTime now;
  final bool isFocused;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glow = _conditionGlow(weather.conditionCode, weather.isDay);

    final upcoming = weather.upcomingHours(now);
    // "Ahora" muestra el valor actual, no el pronosticado para esta hora, así
    // coincide con la temperatura grande.
    final hours = [
      if (upcoming.isNotEmpty)
        WeatherHour(
          time: upcoming.first.time,
          tempC: weather.tempC,
          conditionCode: weather.conditionCode,
          isDay: weather.isDay,
        ),
      ...upcoming.skip(1),
    ];

    return HomeCard(
      glow: glow,
      focused: isFocused,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          // El ícono va primero y más chico: está, pero no manda.
          TvWeatherAnimatedIcon(
            lottieUrl: WeatherIconMapper.getLottieUrl(
              code: weather.conditionCode,
              isDay: weather.isDay,
            ),
            updateToken: weather.lastUpdated.millisecondsSinceEpoch,
            size: 56,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 214,
            child: _Current(weather: weather, place: place ?? weather.city),
          ),
          if (hours.length > 1) ...[
            Container(
              width: 1,
              height: 72,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
            Expanded(child: _HourlyStrip(hours: hours)),
          ] else
            const Spacer(),
        ],
      ),
    );
  }

  /// Color del halo según el clima: cálido con sol, frío de noche o con
  /// lluvia/nieve, gris con nubes o niebla.
  static Color _conditionGlow(int? code, bool isDay) {
    final kind = weatherKindOf(code);
    if (kind == WeatherKind.rain) return const Color(0xFF5FA8F5);
    if (kind == WeatherKind.snow) return const Color(0xFFB8E4FF);
    if (!isDay) return const Color(0xFF8A94FF);
    if (kind == WeatherKind.clear) return const Color(0xFFFFB547);
    return const Color(0xFF9FB1BE);
  }
}

/// Estado actual compacto: ciudad, temperatura + condición y máx/mín, y una
/// línea con sensación térmica y lluvia.
class _Current extends StatelessWidget {
  const _Current({required this.weather, required this.place});

  final WeatherData weather;
  final String place;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;

    final range = [
      if (weather.maxTempC != null)
        LocaleKeys.home_weather_max.tr(
          namedArgs: {'temp': '${weather.maxTempC!.round()}'},
        ),
      if (weather.minTempC != null)
        LocaleKeys.home_weather_min.tr(
          namedArgs: {'temp': '${weather.minTempC!.round()}'},
        ),
    ].join('  ·  ');

    final extra = [
      if (weather.feelsLikeC != null)
        LocaleKeys.home_weather_feels_like.tr(
          namedArgs: {'temp': '${weather.feelsLikeC!.round()}'},
        ),
      if ((weather.chanceOfRain ?? 0) > 0)
        LocaleKeys.home_weather_rain.tr(
          namedArgs: {'chance': '${weather.chanceOfRain}'},
        ),
    ].join('  ·  ');

    final small = MoaiText.body(
      context,
      color: muted,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (place.isNotEmpty)
          Text(
            place,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              color: muted,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        Row(
          children: [
            Text(
              '${weather.formattedTemp}°',
              style: MoaiText.display(
                context,
                color: scheme.onSurface,
                fontSize: 40,
                fontWeight: FontWeight.w500,
                height: 1.15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.condition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  if (range.isNotEmpty) Text(range, maxLines: 1, style: small),
                ],
              ),
            ),
          ],
        ),
        if (extra.isNotEmpty)
          Text(
            extra,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small,
          ),
      ],
    );
  }
}

/// Próximas horas: temperatura arriba, curva con un punto por hora, ícono y
/// hora abajo. La primera es la hora en curso ("Ahora") y va resaltada.
class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.hours});

  final List<WeatherHour> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    Widget row(Widget Function(int i, WeatherHour h) cell) => Row(
      children: [
        for (var i = 0; i < hours.length; i++)
          Expanded(child: Center(child: cell(i, hours[i]))),
      ],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        row(
          (i, h) => Text(
            '${h.formattedTemp}°',
            style: MoaiText.body(
              context,
              color: i == 0 ? scheme.onSurface : scheme.onSurfaceVariant,
              fontSize: 12.5,
              fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 22,
          width: double.infinity,
          child: CustomPaint(
            painter: _TempCurvePainter(
              temps: [for (final h in hours) h.tempC],
              line: scheme.primary,
              dot: scheme.onSurfaceVariant,
              highlight: scheme.primary,
              ring: scheme.surface,
            ),
          ),
        ),
        const SizedBox(height: 2),
        row(
          (i, h) => TvWeatherAnimatedIcon(
            lottieUrl: WeatherIconMapper.getLottieUrl(
              code: h.conditionCode,
              isDay: h.isDay,
            ),
            size: 22,
          ),
        ),
        const SizedBox(height: 2),
        row(
          (i, h) => Text(
            i == 0
                ? LocaleKeys.home_weather_now.tr()
                : DateFormat('HH:mm').format(h.time),
            style: MoaiText.body(
              context,
              color: i == 0 ? scheme.primary : scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Curva suave (Catmull-Rom) que une las temperaturas, con un relleno que se
/// desvanece hacia abajo y un punto por hora; el primero resaltado.
class _TempCurvePainter extends CustomPainter {
  _TempCurvePainter({
    required this.temps,
    required this.line,
    required this.dot,
    required this.highlight,
    required this.ring,
  });

  final List<double> temps;
  final Color line;
  final Color dot;
  final Color highlight;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.length < 2) return;
    const pad = 5.0;
    final lo = temps.reduce((a, b) => a < b ? a : b);
    final hi = temps.reduce((a, b) => a > b ? a : b);
    final span = hi - lo;
    final step = size.width / temps.length;

    final points = [
      for (var i = 0; i < temps.length; i++)
        Offset(
          step * (i + 0.5),
          span == 0
              ? size.height / 2
              : pad + (size.height - pad * 2) * (1 - (temps[i] - lo) / span),
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : p2;
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }

    final fill = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.16), line.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = line.withValues(alpha: 0.75),
    );

    for (var i = 1; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        2.5,
        Paint()..color = dot.withValues(alpha: 0.7),
      );
    }
    canvas.drawCircle(points.first, 5.5, Paint()..color = ring);
    canvas.drawCircle(points.first, 4, Paint()..color = highlight);
  }

  @override
  bool shouldRepaint(_TempCurvePainter old) =>
      old.line != line ||
      old.dot != dot ||
      old.highlight != highlight ||
      old.ring != ring ||
      !_sameTemps(old.temps, temps);

  static bool _sameTemps(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
