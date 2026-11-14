import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Carga la fuente real de la app (de `assets/fonts`) en vez de la de prueba
/// de Flutter, para que los tests de desbordes midan los textos como en el
/// TV. Llamar en `setUpAll`.
Future<void> loadRealFonts() async {
  if (_loaded) return;
  final loader = FontLoader('Quicksand');
  for (final weight in const ['regular', '500', '600', '700']) {
    final bytes = File(
      'assets/fonts/quicksand-v37-latin-$weight.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
  _loaded = true;
}
