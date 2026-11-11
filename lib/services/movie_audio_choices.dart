import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El audio que el usuario eligió en cada película. Sirve sobre todo para las
/// que traen dos pistas "spa": no hay forma de saber cuál es latino, así que
/// se recuerda la que eligió.
abstract final class MovieAudioChoices {
  static const String _key = 'movie_audio_choices';
  static const int maxEntries = 300;

  static Future<({String code, int occurrence})?> read(String contentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final parts = _decode(prefs.getString(_key))[contentId]?.split(':');
      if (parts == null || parts.length != 2) return null;
      final occurrence = int.tryParse(parts[1]);
      return occurrence == null
          ? null
          : (code: parts[0], occurrence: occurrence);
    } catch (e) {
      debugPrint('[MovieAudioChoices] No se pudo leer: $e');
      return null;
    }
  }

  /// La más nueva queda al final; pasado el tope se olvidan las más viejas.
  static Future<void> save(
    String contentId, {
    required String code,
    required int occurrence,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final choices = _decode(prefs.getString(_key))
        ..remove(contentId)
        ..[contentId] = '$code:$occurrence';
      while (choices.length > maxEntries) {
        choices.remove(choices.keys.first);
      }
      await prefs.setString(_key, jsonEncode(choices));
    } catch (e) {
      debugPrint('[MovieAudioChoices] No se pudo guardar: $e');
    }
  }

  static Map<String, String> _decode(String? raw) {
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
  }
}
