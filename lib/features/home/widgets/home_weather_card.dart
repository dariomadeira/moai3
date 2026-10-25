import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/tv_weather_animated_icon.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/services/weather_icon_mapper.dart';
import 'package:moai3/services/weather_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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
  });

  final WeatherData weather;

  /// Hora de referencia para elegir las próximas horas (la refresca el Inicio).
  final DateTime now;
  final bool isFocused;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dark = scheme.brightness == Brightness.dark;
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

    return MoaiGlass(
      borderRadius: radius,
      elevated: false,
      solid: true,
      focused: isFocused,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // Halo del color del clima detrás del ícono.
            Positioned(
              right: -50,
              top: -70,
              width: 240,
              height: 240,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: dark ? 0.22 : 0.30),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                children: [
                  SizedBox(width: 214, child: _Current(weather: weather)),
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
                  const SizedBox(width: 8),
                  TvWeatherAnimatedIcon(
                    lottieUrl: WeatherIconMapper.getLottieUrl(
                      code: weather.conditionCode,
                      isDay: weather.isDay,
                    ),
                    updateToken: weather.lastUpdated.millisecondsSinceEpoch,
                    size: 84,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Color del halo según el clima: cálido con sol, frío de noche o con
  /// lluvia/nieve, gris con nubes o niebla.
  static Color _conditionGlow(int? code, bool isDay) {
    const rain = {
      1063, 1072, 1087, 1150, 1153, 1168, 1171, 1180, 1183, 1186, 1189, 1192, //
      1195, 1198, 1201, 1240, 1243, 1246, 1273, 1276,
    };
    const snow = {
      1066, 1069, 1114, 1117, 1204, 1207, 1210, 1213, 1216, 1219, 1222, 1225, //
      1237, 1249, 1252, 1255, 1258, 1261, 1264, 1279, 1282,
    };
    if (code != null && rain.contains(code)) return const Color(0xFF5FA8F5);
    if (code != null && snow.contains(code)) return const Color(0xFFB8E4FF);
    if (!isDay) return const Color(0xFF8A94FF);
    if (code == null || code == 1000 || code == 1003) {
      return const Color(0xFFFFB547);
    }
    return const Color(0xFF9FB1BE);
  }
}

/// Estado actual compacto: ciudad, temperatura + condición y máx/mín, y una
/// línea con sensación térmica y lluvia.
class _Current extends StatelessWidget {
  const _Current({required this.weather});

  final WeatherData weather;

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
        if (weather.city.isNotEmpty)
          Text(
            weather.city,
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
                fontSize: 46,
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
