import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/tv_settings_provider.dart';

/// Búsqueda con ←/→ en el reproductor: un toque salta 10 s y, mantenida, la
/// flecha acelera (30 s, 1 min, 5 min) para cruzar la película sin apretar
/// cientos de veces.
abstract final class MovieScrub {
  /// Paso según cuántas repeticiones lleva la flecha apretada.
  static Duration stepFor(int repeats) {
    if (repeats < 8) return const Duration(seconds: 10);
    if (repeats < 20) return const Duration(seconds: 30);
    if (repeats < 40) return const Duration(minutes: 1);
    return const Duration(minutes: 5);
  }

  /// Destino desde [from] en la dirección [forward], sin salirse de la
  /// película (el final queda 1 s antes para no terminarla de un salto).
  static Duration target({
    required Duration from,
    required bool forward,
    required int repeats,
    required Duration total,
  }) {
    final step = stepFor(repeats);
    final next = forward ? from + step : from - step;
    final end = total - const Duration(seconds: 1);
    if (next < Duration.zero) return Duration.zero;
    if (end > Duration.zero && next > end) return end;
    return next;
  }
}

/// "1:05:09" o "5:09".
String formatPlayerTime(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Diferencia con signo para la búsqueda: "+2:30", "−0:40".
String formatPlayerDelta(Duration d) {
  final sign = d.isNegative ? '−' : '+';
  return '$sign${formatPlayerTime(d.abs())}';
}

/// Código de idioma de dos letras de un audio: la API manda "spa", "eng",
/// "esp"…; ExoPlayer, "es", "en", "es-419"… `null` si no se reconoce.
String? audioLanguageCode(String code) {
  final c = code.toLowerCase().trim();
  const three = {
    'spa': 'es', 'esp': 'es', 'cas': 'es', //
    'eng': 'en', 'ing': 'en',
    'por': 'pt',
    'jpn': 'ja', 'jap': 'ja',
    'kor': 'ko', 'cor': 'ko',
    'fra': 'fr', 'fre': 'fr',
    'ita': 'it',
    'deu': 'de', 'ger': 'de', 'ale': 'de',
  };
  const two = {'es', 'en', 'pt', 'ja', 'ko', 'fr', 'it', 'de'};
  if (c.length >= 3 && three.containsKey(c.substring(0, 3))) {
    return three[c.substring(0, 3)];
  }
  if (c.length >= 2 && two.contains(c.substring(0, 2))) {
    return c.substring(0, 2);
  }
  return null;
}

/// Idioma de un audio para mostrar ("Español", "Latino", "Inglés"…). [code]
/// es un código ("spa", "es-419") o la lista de la API ("spa,spa,eng", se
/// usa el primero); [trackLabel], el nombre de la pista si lo hay.
String audioLanguageLabel(String code, {String? trackLabel}) {
  final first = code.split(',').first.trim();
  final hint = '$first ${trackLabel ?? ''}'.toLowerCase();
  if (hint.contains('lat') || hint.contains('419')) {
    return LocaleKeys.movies_audio_latino.tr();
  }
  final key = switch (audioLanguageCode(first)) {
    'es' => LocaleKeys.movies_audio_spanish,
    'en' => LocaleKeys.movies_audio_english,
    'pt' => LocaleKeys.movies_audio_portuguese,
    'ja' => LocaleKeys.movies_audio_japanese,
    'ko' => LocaleKeys.movies_audio_korean,
    'fr' => LocaleKeys.movies_audio_french,
    'it' => LocaleKeys.movies_audio_italian,
    'de' => LocaleKeys.movies_audio_german,
    _ => null,
  };
  if (key != null) return key.tr();
  return first.isEmpty
      ? LocaleKeys.movies_audio_default.tr()
      : first.toUpperCase();
}

/// Subtítulo a mostrar según el ajuste; `null` si están apagados o la
/// película no trae ese idioma.
VodSubtitleOption? pickSubtitle(
  MovieSubtitleLanguage preference,
  List<VodSubtitleOption> subtitles,
) {
  final wanted = switch (preference) {
    MovieSubtitleLanguage.off => null,
    MovieSubtitleLanguage.spanish => 'es',
    MovieSubtitleLanguage.english => 'en',
  };
  if (wanted == null) return null;
  for (final s in subtitles) {
    if (s.url.isNotEmpty &&
        audioLanguageCode(s.language.isNotEmpty ? s.language : s.name) ==
            wanted) {
      return s;
    }
  }
  return null;
}

/// Idioma que se le pide al motor según el ajuste y los audios que trae la
/// película ([audioInfo] de la API, p. ej. "spa,spa,eng"). `null`: sin
/// preferencia (el motor usa el primero).
String? preferredAudioCode(MovieAudioLanguage preference, String audioInfo) {
  final codes = [
    for (final part in audioInfo.split(',')) ?audioLanguageCode(part),
  ];
  switch (preference) {
    case MovieAudioLanguage.spanish:
      return 'es';
    case MovieAudioLanguage.english:
      return 'en';
    case MovieAudioLanguage.original:
      // El primero que no es español; con sólo español, sin preferencia.
      for (final code in codes) {
        if (code != 'es') return code;
      }
      return null;
  }
}

/// Calidad para mostrar: "1080P HD" o "FHD 1080" → "1080p".
String qualityLabel(String quality) {
  final q = quality.toUpperCase();
  if (q.contains('4K') || q.contains('2160')) return '4K';
  for (final p in const ['1080', '720', '480', '360']) {
    if (q.contains(p)) return '${p}p';
  }
  return quality.trim();
}
