import 'dart:io';

import 'package:flutter/services.dart';

bool _loaded = false;

/// Carga la fuente real de la app (de `assets/fonts`) en vez de la de prueba
/// de Flutter, para que los tests de desbordes midan los textos como en el
/// TV. Llamar en `setUpAll`.
Future<void> loadRealFonts() async {
  if (_loaded) return;
  final bytes = File(
    'assets/fonts/varela-round-v21-latin-regular.ttf',
  ).readAsBytesSync();
  await (FontLoader(
    'VarelaRound',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  _loaded = true;
}
