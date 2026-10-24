import 'dart:convert';
import 'dart:io';
import 'dart:ui';

// ignore: implementation_imports
import 'package:easy_localization/src/localization.dart';
// ignore: implementation_imports
import 'package:easy_localization/src/translations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga `es.json` real para el test actual, así `tr()` devuelve el texto en
/// español en vez de la clave. Se descarga sola al terminar el test.
void useSpanishTranslations() {
  final map = jsonDecode(
    File('assets/translations/es.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  Localization.load(const Locale('es'), translations: Translations(map));
  addTearDown(() => Localization.load(const Locale('es')));
}
