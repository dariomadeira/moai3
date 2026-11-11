import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián de assets: cada imagen suelta de `assets/images/` y `assets/svgs/`
/// la nombra el código con su ruta completa, y cada fuente de
/// `assets/fonts/` está en el pubspec. Lo que nadie nombra pesa en el APK
/// sin servir: se borra (las fuentes de origen van en `assets_src/`).
void main() {
  final code = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.readAsStringSync(),
  ].join('\n');

  List<String> filesIn(String dir) => [
    for (final f in Directory(dir).listSync())
      if (f is File) f.path.replaceAll(r'\', '/'),
  ];

  test('no hay imágenes sin uso', () {
    final unused = [
      for (final path in [
        ...filesIn('assets/images'),
        ...filesIn('assets/svgs'),
      ])
        if (!code.contains(path)) path,
    ];
    expect(unused, isEmpty);
  });

  test('no hay fuentes fuera del pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final unused = [
      for (final path in filesIn('assets/fonts'))
        if (!pubspec.contains(path)) path,
    ];
    expect(unused, isEmpty);
  });
}
