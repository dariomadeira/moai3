/// Mapeador de códigos de condiciones meteorológicas de WeatherAPI a URLs CDN de Meteocons Lottie.
class WeatherIconMapper {
  static const String _cdnBase =
      'https://cdn.jsdelivr.net/npm/@meteocons/lottie@0.1.0/fill';

  /// Retorna la URL CDN de Meteocons para la condición y momento del día dados.
  ///
  /// [code]: Código numérico de WeatherAPI (ej: 1000 = Despejado).
  /// [isDay]: true si es de día, false si es de noche.
  static String getLottieUrl({int? code, bool isDay = true}) {
    if (code == null) {
      return isDay ? '$_cdnBase/clear-day.json' : '$_cdnBase/clear-night.json';
    }

    switch (code) {
      // Despejado / Soleado
      case 1000:
        return isDay ? '$_cdnBase/clear-day.json' : '$_cdnBase/clear-night.json';

      // Parcialmente nublado
      case 1003:
        return isDay
            ? '$_cdnBase/partly-cloudy-day.json'
            : '$_cdnBase/partly-cloudy-night.json';

      // Nublado
      case 1006:
        return '$_cdnBase/cloudy.json';

      // Cubierto / Overcast
      case 1009:
        return isDay
            ? '$_cdnBase/overcast-day.json'
            : '$_cdnBase/overcast-night.json';

      // Niebla / Neblina
      case 1030: // Mist
        return '$_cdnBase/mist.json';
      case 1135: // Fog
      case 1147: // Freezing fog
        return isDay ? '$_cdnBase/fog-day.json' : '$_cdnBase/fog-night.json';

      // Llovizna
      case 1063: // Patchy rain possible
      case 1150: // Patchy light drizzle
      case 1153: // Light drizzle
      case 1168: // Freezing drizzle
      case 1171: // Heavy freezing drizzle
        return isDay
            ? '$_cdnBase/partly-cloudy-day-drizzle.json'
            : '$_cdnBase/partly-cloudy-night-drizzle.json';

      // Lluvia ligera y moderada
      case 1180: // Patchy light rain
      case 1183: // Light rain
      case 1186: // Moderate rain at times
      case 1189: // Moderate rain
      case 1240: // Light rain shower
        return isDay
            ? '$_cdnBase/partly-cloudy-day-rain.json'
            : '$_cdnBase/partly-cloudy-night-rain.json';

      // Lluvia fuerte / Torrencial
      case 1192: // Heavy rain at times
      case 1195: // Heavy rain
      case 1243: // Moderate or heavy rain shower
      case 1246: // Torrential rain shower
        return '$_cdnBase/rain.json';

      // Nieve y aguanieve
      case 1066: // Patchy snow possible
      case 1069: // Patchy sleet possible
      case 1072: // Patchy freezing drizzle possible
      case 1114: // Blowing snow
      case 1117: // Blizzard
      case 1204: // Light sleet
      case 1207: // Moderate or heavy sleet
      case 1210: // Patchy light snow
      case 1213: // Light snow
      case 1216: // Patchy moderate snow
      case 1219: // Moderate snow
      case 1222: // Patchy heavy snow
      case 1225: // Heavy snow
      case 1249: // Light sleet showers
      case 1252: // Moderate or heavy sleet showers
      case 1255: // Light snow showers
      case 1258: // Moderate or heavy snow showers
        return isDay
            ? '$_cdnBase/partly-cloudy-day-snow.json'
            : '$_cdnBase/partly-cloudy-night-snow.json';

      // Granizo
      case 1237: // Ice pellets
      case 1261: // Light showers of ice pellets
      case 1264: // Moderate or heavy showers of ice pellets
        return '$_cdnBase/hail.json';

      // Tormenta eléctrica
      case 1087: // Thundery outbreaks possible
        return isDay
            ? '$_cdnBase/thunderstorms-day.json'
            : '$_cdnBase/thunderstorms-night.json';

      // Tormenta con lluvia
      case 1273: // Patchy light rain with thunder
      case 1276: // Moderate or heavy rain with thunder
        return isDay
            ? '$_cdnBase/thunderstorms-day-rain.json'
            : '$_cdnBase/thunderstorms-night-rain.json';

      // Tormenta con nieve/granizo
      case 1279: // Patchy light snow with thunder
      case 1282: // Moderate or heavy snow with thunder
        return isDay
            ? '$_cdnBase/thunderstorms-day-snow.json'
            : '$_cdnBase/thunderstorms-night-snow.json';

      default:
        return isDay ? '$_cdnBase/clear-day.json' : '$_cdnBase/clear-night.json';
    }
  }
}
