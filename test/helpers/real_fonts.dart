import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Carga las fuentes reales de la app (de `assets/fonts`) en vez de la de
/// prueba de Flutter, para que los tests de desbordes midan los textos como
/// en el TV. Llamar en `setUpAll`.
Future<void> loadRealFonts() async {
  if (_loaded) return;
  for (final (family, prefix, weights) in [
    ('VarelaRound', 'varela-round-v21-latin', ['regular']),
    (
      'MPLUSRounded1c',
      'm-plus-rounded-1c-v22-latin',
      ['300', 'regular', '500', '700', '800'],
    ),
    (
      'Onest',
      'onest-v11-latin',
      ['300', 'regular', '500', '600', '700', '800'],
    ),
    (
      'Unbounded',
      'unbounded-v12-latin',
      ['300', 'regular', '500', '600', '700', '800'],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final weight in weights) {
      final bytes = File('assets/fonts/$prefix-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
  _loaded = true;
}
