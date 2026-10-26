import 'package:flutter/material.dart';

/// Qué tiempo hace, según el código de condición de WeatherAPI.
enum WeatherKind { clear, cloudy, rain, snow }

WeatherKind weatherKindOf(int? code) {
  const rain = {
    1063, 1072, 1087, 1150, 1153, 1168, 1171, 1180, 1183, 1186, 1189, 1192, //
    1195, 1198, 1201, 1240, 1243, 1246, 1273, 1276,
  };
  const snow = {
    1066, 1069, 1114, 1117, 1204, 1207, 1210, 1213, 1216, 1219, 1222, 1225, //
    1237, 1249, 1252, 1255, 1258, 1261, 1264, 1279, 1282,
  };
  if (code == null || code == 1000 || code == 1003) return WeatherKind.clear;
  if (rain.contains(code)) return WeatherKind.rain;
  if (snow.contains(code)) return WeatherKind.snow;
  return WeatherKind.cloudy;
}

/// Hay tormenta eléctrica (truenos, con lluvia o con nieve).
bool isStormCode(int? code) =>
    const {1087, 1273, 1276, 1279, 1282}.contains(code);

/// La foto del cielo del Inicio para cada momento y tiempo
/// (`assets/images/home_sky/`, ver CREDITOS.md ahí).
enum HomeSkyScene {
  dawn('amanecer'),
  day('dia'),
  cloudy('nublado'),
  dusk('atardecer'),
  night('noche'),
  nightRain('noche_lluvia'),
  storm('tormenta'),
  snow('nieve');

  const HomeSkyScene(this.file);

  final String file;

  String get asset => 'assets/images/home_sky/$file.webp';

  /// Amanecer de 5 a 8, día de 8 a 17, atardecer de 17 a 20 y noche el
  /// resto. El tiempo manda sobre la hora cuando cambia el cielo: tormenta,
  /// nieve, lluvia (de día, nublado; de noche, ventana con lluvia) y
  /// nublado de día. Nublado al amanecer, al atardecer o de noche queda con
  /// la foto de la hora.
  static HomeSkyScene at(DateTime time, {int? weatherCode}) {
    final h = time.hour;
    final isNight = h >= 20 || h < 5;
    if (isStormCode(weatherCode)) return storm;
    switch (weatherKindOf(weatherCode)) {
      case WeatherKind.snow:
        return snow;
      case WeatherKind.rain:
        return isNight ? nightRain : cloudy;
      case WeatherKind.cloudy:
        if (h >= 8 && h < 17) return cloudy;
      case WeatherKind.clear:
        break;
    }
    if (h >= 5 && h < 8) return dawn;
    if (h >= 8 && h < 17) return day;
    if (h >= 17 && h < 20) return dusk;
    return night;
  }
}

/// Colores del cielo para una hora y un tiempo: el principal (arriba a la
/// izquierda) y el del brillo (arriba a la derecha). Respaldo si la foto no
/// se puede cargar.
@immutable
class HomeSkyColors {
  const HomeSkyColors(this.main, this.glow);

  final Color main;
  final Color glow;

  /// Noche violeta, amanecer anaranjado, día celeste, atardecer magenta. Con
  /// lluvia o nublado se apaga hacia el gris; con nieve, hacia el hielo.
  factory HomeSkyColors.at(DateTime time, {int? weatherCode}) {
    final h = time.hour;
    final HomeSkyColors base;
    if (h >= 5 && h < 8) {
      base = const HomeSkyColors(Color(0xFFE0785A), Color(0xFFF2B26B));
    } else if (h >= 8 && h < 17) {
      base = const HomeSkyColors(Color(0xFF2F7DE1), Color(0xFF38BDF8));
    } else if (h >= 17 && h < 20) {
      base = const HomeSkyColors(Color(0xFFC2416E), Color(0xFFF59E0B));
    } else {
      base = const HomeSkyColors(Color(0xFF4338CA), Color(0xFF8B5CF6));
    }
    return switch (weatherKindOf(weatherCode)) {
      WeatherKind.clear => base,
      WeatherKind.cloudy => base._toward(const Color(0xFF64748B), 0.3),
      WeatherKind.rain => base._toward(const Color(0xFF475569), 0.45),
      WeatherKind.snow => base._toward(const Color(0xFFCBE6FF), 0.35),
    };
  }

  HomeSkyColors _toward(Color other, double t) =>
      HomeSkyColors(Color.lerp(main, other, t)!, Color.lerp(glow, other, t)!);

  @override
  bool operator ==(Object other) =>
      other is HomeSkyColors && other.main == main && other.glow == glow;

  @override
  int get hashCode => Object.hash(main, glow);
}

/// "Cielo del momento": arriba del panel del Inicio, la foto del cielo de
/// esta hora y este tiempo, oscurecida y desvaneciéndose hacia abajo y hacia
/// la izquierda (como el fondo del detalle de películas).
///
/// El oscurecido y los desvanecidos ya vienen en las fotos (WebP con
/// transparencia, recortadas a la proporción del recuadro): se dibujan como
/// una imagen común, sin máscaras ni filtros que el TV recalcule en cada
/// cuadro. Cambia, con un fundido, sólo cuando cambia la escena.
class HomeSkyBackdrop extends StatelessWidget {
  const HomeSkyBackdrop({super.key, required this.time, this.weatherCode});

  final DateTime time;
  final int? weatherCode;

  /// Qué parte del panel ocupa la foto, desde arriba (las fotos están
  /// recortadas a esta proporción en el TV, ~2,6:1).
  static const double _heightFactor = 0.62;

  @override
  Widget build(BuildContext context) {
    final scene = HomeSkyScene.at(time, weatherCode: weatherCode);

    return IgnorePointer(
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight * _heightFactor,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 900),
                  // Las fotos llenan el recuadro (por defecto quedan a su
                  // tamaño, centradas).
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [...previous, ?current],
                  ),
                  child: _Photo(
                    key: ValueKey(scene),
                    scene: scene,
                    fallback: HomeSkyColors.at(time, weatherCode: weatherCode),
                    cacheWidth:
                        (constraints.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(1, 1280),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// La foto ya preparada. Si no carga, el degradado de colores.
class _Photo extends StatelessWidget {
  const _Photo({
    super.key,
    required this.scene,
    required this.fallback,
    required this.cacheWidth,
  });

  final HomeSkyScene scene;
  final HomeSkyColors fallback;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Image.asset(
      scene.asset,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      cacheWidth: cacheWidth,
      // Las fotos vienen oscurecidas para el tema oscuro (texto blanco). En
      // el claro el texto es oscuro: un velo blanco sobre la foto (sólo
      // donde hay foto) la deja en un cielo suave que no tapa el saludo. Es
      // un filtro al dibujar la imagen, sin capas extra.
      color: light ? Colors.white.withValues(alpha: 0.62) : null,
      colorBlendMode: light ? BlendMode.srcATop : null,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              fallback.main.withValues(alpha: 0.35),
              fallback.glow.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
